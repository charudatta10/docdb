create or replace package body docdb_parse

as

	procedure meta_clob_to_lines (
		parser				in out nocopy		parse_type
		, meta_clob			in 					clob
	)

	as

		var_clob_line 							varchar2(4000);
		var_clob_line_count 					number;

	begin

		parser.current_data.lines.delete;

		var_clob_line_count := length(meta_clob) - nvl(length(replace(meta_clob,chr(10))),0) + 1;
 		for i in 1.. var_clob_line_count loop
			var_clob_line := regexp_substr(meta_clob,'^.*$',1,i,'m');
			parser.current_data.lines(i) := var_clob_line;
		end loop;

		exception
			when others then
				raise;

	end meta_clob_to_lines;

	procedure parse_curr_documentation (
		parser 				in out nocopy 		parse_type
		, line_start 		in 					number
		, line_end 			in 					number
	)

	as

		in_description		boolean := false;

	begin

		for i in line_start..line_end loop
			-- Lines should already be trimmed
			if substr(parser.current_data.lines(i), 1, 3) = '/**' then
				in_description := true;
				if length(parser.current_data.lines(i)) > 4 then
					parser.current_data.description := substr(parser.current_data.lines(i), 4);
				end if;
			elsif in_description and instr(parser.current_data.lines(i), '@') = 0 then
				-- Just add to description. Check if we have text or we should add a <br>
				if parser.current_data.lines(i) = '*' then
					-- Add a <br> for each empty description line
					parser.current_data.description := parser.current_data.description || ' <br> ';
				else
					-- Just add text after the * character
					parser.current_data.description := parser.current_data.description || substr(parser.current_data.lines(i), 2);
				end if;
			elsif in_description and instr(parser.current_data.lines(i), '@') > 0 then
				-- Out of description
				in_description := false;
				-- Parse line
				docdb_tools.parse_documentation_line(parser, i);
			end if;
		end loop;

	end parse_curr_documentation;

	procedure parse_curr (
		parser 				in out nocopy 		parse_type
		, parse_obj_type	in 					varchar2
		, info_index		in 					number
	)

	as

		expect_comment_first			boolean := true;
		documentation_start				number := null;
		documentation_end				number := null;
		documentation_pkg_block			boolean := false;
		program_spec_met				boolean := false;

	begin

		if parse_obj_type = 'PACKAGE' then

			-- Set initial parameters
			parser.current_data.package_name := substr(parser.info.package_list(info_index), instr(parser.info.package_list(info_index), '.') + 1);
			parser.current_data.owner := substr(parser.info.package_list(info_index), 1, instr(parser.info.package_list(info_index), '.') - 1);

			-- Run preparation steps
			meta_clob_to_lines(
				parser
				, docdb_tools.get_metadata_clob(
					'PACKAGE_SPEC'
					, parser.current_data.package_name
					, parser.current_data.owner
				)
			);
			parser.counters.package_counter := parser.counters.package_counter + 1;
		elsif parse_obj_type = 'PROCEDURE' then

			-- Set initial parameters
			parser.current_data.package_name := null;
			parser.current_data.program_name := substr(parser.info.package_list(info_index), instr(parser.info.package_list(info_index), '.') + 1);
			parser.current_data.owner := substr(parser.info.package_list(info_index), 1, instr(parser.info.package_list(info_index), '.') - 1);
			parser.current_data.is_procedure := true;
			parser.current_data.is_function := false;
			expect_comment_first := false;

			-- Run preparation steps
			meta_clob_to_lines(
				parser
				, docdb_tools.get_metadata_clob(
					'PROCEDURE'
					, parser.current_data.program_name
					, parser.current_data.owner
				)
			);
			parser.counters.program_counter := parser.counters.program_counter + 1;
		elsif parse_obj_type = 'FUNCTION' then

			-- Set initial parameters
			parser.current_data.package_name := null;
			parser.current_data.program_name := substr(parser.info.package_list(info_index), instr(parser.info.package_list(info_index), '.') + 1);
			parser.current_data.owner := substr(parser.info.package_list(info_index), 1, instr(parser.info.package_list(info_index), '.') - 1);
			parser.current_data.is_procedure := false;
			parser.current_data.is_function := true;
			expect_comment_first := false;

			-- Run preparation steps
			meta_clob_to_lines(
				parser
				, docdb_tools.get_metadata_clob(
					'FUNCTION'
					, parser.current_data.program_name
					, parser.current_data.owner
				)
			);
			parser.counters.program_counter := parser.counters.program_counter + 1;
		end if;

		-- Run the parse loop
		for i in 1..parser.current_data.lines.count loop
			docdb_tools.prepare_line_for_parse(parser, i);

			if substr(parser.current_data.lines(i), 1, 3) = '/**' then
				documentation_start := i;
			elsif substr(parser.current_data.lines(i), -2, 2) = '*/' then
				documentation_end := i;
			elsif upper(substr(parser.current_data.lines(i), 1, 9)) = 'PROCEDURE' then
				program_spec_met := true;
			elsif upper(substr(parser.current_data.lines(i), 1, 8)) = 'FUNCTION' then
				program_spec_met := true;
			end if;

			if documentation_start is not null and documentation_end is not null then
				-- Send off documentation part for parsing
				parse_curr_documentation(parser, documentation_start, documentation_end);

				-- Should we continue or drop out of loop
				if not expect_comment_first then
					-- Stand alone procedure or function, pase dictionary and exit
					docdb_tools.parse_program_dictionary(parser);
					exit;
				end if;

				-- If we continue we need to grab the program name and type before we parse dictionary
				docdb_tools.extract_package_program_name(parser, documentation_end, documentation_pkg_block);
				if documentation_pkg_block then
					docdb_tools.parse_current_as_package_doc(parser);
				else
					docdb_tools.parse_program_dictionary(parser);
				end if;

				-- When parsing of this section is done, reset start and end
				documentation_start := null;
				documentation_end := null;
				program_spec_met := false;
				documentation_pkg_block := false;
				docdb_tools.reset_current_parse(parser);
			elsif expect_comment_first and program_spec_met and documentation_start is null and documentation_end is null then
				-- We are in a package, and there is no documentation for a program. We still parse dictionary
				docdb_tools.extract_package_program_name(parser, i - 1, documentation_pkg_block);
				docdb_tools.parse_program_dictionary(parser);

				program_spec_met := false;
				docdb_tools.reset_current_parse(parser);
			end if;

		end loop;

	end parse_curr;

	procedure parse_session_start (
		parser				in out nocopy		parse_type
		, name				in 					varchar2			default null
		, description 		in 					clob				default null
	)

	as

	begin

		-- Set the initial parameters
		parser.parse_id := 1;
		parser.run_id := 1;
		parser.run_date_start := sysdate;
		parser.run_name := name;
		parser.run_description := description;
		-- Counters
		parser.counters.package_counter := 0;
		parser.counters.program_counter := 0;
		parser.counters.parameter_counter := 0;
		parser.counters.program_attr_counter := 0;

	end parse_session_start;

	procedure parse_session_end (
		parser				in out nocopy		parse_type
	)

	as

	begin

		-- Set the final parameters
		parser.run_date_end := sysdate;

	end parse_session_end;

	procedure parse (
		parser 				in out nocopy 		parse_type
	)

	as

	begin

		-- Parse packages
		if parser.info.package_list.count > 0 then
			for objs in 1..parser.info.package_list.count loop
				parse_curr(parser, 'PACKAGE', objs);
			end loop;
		end if;

		-- Parse procedures
		if parser.info.procedure_list.count > 0 then
			for objs in 1..parser.info.procedure_list.count loop
				parse_curr(parser, 'PROCEDURE', objs);
			end loop;
		end if;

		-- Parse functions
		if parser.info.function_list.count > 0 then
			for objs in 1..parser.info.function_list.count loop
				parse_curr(parser, 'FUNCTION', objs);
			end loop;
		end if;

	end parse;

	procedure add_schema_to_session (
		parser 				in out nocopy 		parse_type
		, schema 			in 					varchar2
		, parse_packages	in 					boolean 			default true
		, parse_procedures 	in 					boolean				default false
		, parse_functions	in 					boolean				default false
	)

	as

		cursor get_names(obj_type varchar2) is
			select 
				object_name
				, object_id
			from 
				all_objects
			where
				owner = upper(schema)
			and
				object_type = obj_type;

	begin

		-- Add the schema
		parser.info.schema_list(parser.info.schema_list.count + 1) := upper(schema);

		-- Add packages
		if parse_packages then
			for obj in get_names('PACKAGE') loop
				parser.info.package_list(parser.info.package_list.count + 1) := parser.info.schema_list(parser.info.schema_list.count) || '.' || obj.object_name;
			end loop;
		end if;

		if parse_procedures then
			for obj in get_names('PROCEDURE') loop
				parser.info.procedure_list(parser.info.procedure_list.count + 1) := parser.info.schema_list(parser.info.schema_list.count) || '.' || obj.object_name;
			end loop;
		end if;

		if parse_functions then
			for obj in get_names('FUNCTION') loop
				parser.info.function_list(parser.info.function_list.count + 1) := parser.info.schema_list(parser.info.schema_list.count) || '.' || obj.object_name;
			end loop;
		end if;

	end add_schema_to_session;

end docdb_parse;
/