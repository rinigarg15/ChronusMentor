var playApp = angular.module('playMatch',[]);

playApp.controller('PlayMatchCtrl', ['$scope', '$http', function ($scope, $http) {
  $scope.configs = matchConfigs;
  $scope.isMatch = true;
  $scope.computeFscoreURL = computeFscoreURL;
  $scope.netScore = 0.0;

  $scope.getTimes=function(n){
    return new Array(n);
  };

  $scope.getFieldScore = function(mc){
    $http({
      method: 'GET',
      url: $scope.computeFscoreURL,
      params: $scope.constructParamHash(mc)
    }).success(function(data){
      if(data.score != mc.fscore){
        jQueryHighlight("#config_" + mc.id + " .cjs_fscore", 1000);
      }
      mc.fscore = data.score;
    });
  };

  $scope.constructParamHash = function(mc){
    var paramHash = {}
    paramHash["config_id"] = mc.id;
    paramHash["sq_type"] = mc.questions[0].type;
    paramHash["mq_type"] = mc.questions[1].type;
    paramHash["sq_value"] = $scope.getValueofQuestion(mc.questions[0]);
    paramHash["mq_value"] = $scope.getValueofQuestion(mc.questions[1]);
    return paramHash;
  };

  $scope.getValueofQuestion = function(question){
    var val;

    if(question.type == 3){
      val = JSON.stringify($scope.pushMultiChoice(question)); 
    }else if(question.type == 15){
      val = JSON.stringify($scope.pushMultiChoiceOrdered(question));
    }else{
      val = question.value;
    }

    return val
  };

  $scope.pushMultiChoice = function(question){
    var selectedChoices = []
    var schoices = question.selectedChoices;
    for(sc in schoices){
      if(schoices[sc] == true){
        selectedChoices.push(sc)
      }
    }
    return selectedChoices;
  };

  $scope.pushMultiChoiceOrdered = function(question){
    var selectedChoices = []
    var schoices = question.selectedChoices;
    for(var i = 0; i < question.count ; i++){
      if(schoices[i] && !schoices[i].blank()){
        selectedChoices.push(schoices[i]);
      }
    }
    return selectedChoices.uniq();
  };

  $scope.updateCanMatch = function(mc){
    if(mc.operator * (mc.fscore - mc.threshold) < 0){
      mc.isMatch = false;
      return {color: "red", value: "No"};
    }else{
      mc.isMatch = true;
      return {color: "green", value: "Yes"};
    }
  };

  $scope.updatematchWeight = function(mc){
    var newscore;
    var returnVal;

    if(mc.isMatch){
      newscore = mc.fscore * mc.weight;
      returnVal = newscore.toFixed(2);
    }else{
      newscore = 0.0;
      returnVal = "Not Applicable";
    }

    if(mc.matchScore != newscore){
      jQueryHighlight("#config_" + mc.id + " .cjs_mscore", 1000);
    }
    mc.matchScore = newscore; 

    return returnVal;
  };

  $scope.updateTotalCanMatch= function(){
    $scope.isMatch = true;

    angular.forEach($scope.configs, function(mc){
      $scope.isMatch = $scope.isMatch && mc.isMatch;
    });

    if($scope.isMatch){
      return {color: "green", value: "Yes"};
    }else{
      return {color: "red", value: "No"};
    }
  };


  $scope.updatematchTotalWeight= function(){
    if($scope.isMatch){
      var totalWeight = 0;
      var totalScore = 0;

      angular.forEach($scope.configs, function(mc) {
        totalScore += mc.matchScore;
        totalWeight += Math.abs(mc.weight);
      });

      if(totalWeight != 0){
        finalscore = totalScore / totalWeight;
      }else{
        finalscore = 0.0;
      }
    }else{
      finalscore = 0.0;
    }

    if(finalscore != $scope.netScore){
      jQueryHighlight("#netscore", 1000);
    }

    $scope.netScore = finalscore;
    return $scope.netScore.toFixed(2);
  };
}]);