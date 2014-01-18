docdbControllers.factory("docdbQueryFac", function(){
    return { queryObject: "" }
});

docdbControllers.controller('PackageDetailCtrl', ['$scope', '$routeParams', 'docdbDataFac', 'docdbQueryFac',
  function($scope, $routeParams, docdbDataFac, docdbQueryFac) {
    $scope.packageId = $routeParams.packageId;
    $scope.packages = docdbDataFac.sharedObject;

    $scope.query = docdbQueryFac.queryObject;

    $scope.qChange = function($event) {
        docdbQueryFac.queryObject = $event.srcElement.value;
        elem = document.querySelector('#queryinput');
        elem.value = docdbQueryFac.queryObject;
        $scope.query = docdbQueryFac.queryObject;
    };

    $scope.queryClear = function() {
        docdbQueryFac.queryObject = "";
        elem = document.querySelector('#queryinput');
        elem.value = docdbQueryFac.queryObject;
        $scope.query = docdbQueryFac.queryObject;
        document.querySelector('#queryinput').focus();
    };

    $scope.proc_count = 0;
    $scope.func_count = 0;

    for (var i = 0; i < $scope.packages.packagelist.length; i++) {
    	if ($scope.packages.packagelist[i].id == $scope.packageId) {
    		for (var y = 0; y < $scope.packages.packagelist[i].programs.length; y++) {
    			if ($scope.packages.packagelist[i].programs[y].programType == 'PROCEDURE') {
    				$scope.proc_count++;
    			} else if ($scope.packages.packagelist[i].programs[y].programType == 'FUNCTION') {
    				$scope.func_count++;
    			}
    		}
    	}
    };
  }]);

docdbControllers.controller('PackageListCtrl', ['$scope', 'docdbDataFac', 'docdbQueryFac',
	function ($scope, docdbDataFac, docdbQueryFac) {
  		$scope.packages = docdbDataFac.sharedObject;

        $scope.query = docdbQueryFac.queryObject;

        $scope.qChange = function($event) {
            docdbQueryFac.queryObject = $event.srcElement.value;
            elem = document.querySelector('#queryinput');
            elem.value = docdbQueryFac.queryObject;
            $scope.query = docdbQueryFac.queryObject;
        };

        $scope.queryClear = function($event) {
            docdbQueryFac.queryObject = "";
            elem = document.querySelector('#queryinput');
            elem.value = docdbQueryFac.queryObject;
            $scope.query = docdbQueryFac.queryObject;
            // document.querySelector('#queryinput').focus();
        };
	}]);