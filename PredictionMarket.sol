pragma solidity ^0.4.2;

import "./std/owned.sol";
//import "./std/mortal.sol";
import "./lib/StringUtils.sol";

 contract PredictionMarket is owned {

    mapping (address => bool) roleAdmin;
    mapping (address => bool) roleTrustedSource;

    struct Speculator {
        uint bet;  // speculator's bet
        string answer;  // Indicates if predominantly speculated true or false
    }


    struct Question {
        uint questionId;  // ID of the question
        string question;  // Question
        string answer;   // Answer to the question (Y/N or blank if not answered)
        bool isOver;  // Indicates betting is over
        uint betTotalForYes;  // total amount wei placed on answer "Yes"
        uint betTotalForNo;  // total amount wei placed on answer "No"
        mapping (address => Speculator) speculators;  // speculators
    }

    uint questionsCount;
    mapping (uint => Question) questions;

    event QuestionAdded(uint indexed _questionID, string _question, bool _status, string _log);

    function getQuestion(uint questionID) public constant returns (uint,string, string, uint, uint, bool){
        return (questions[questionID].questionId, questions[questionID].question,questions[questionID].answer,questions[questionID].betTotalForYes,questions[questionID].betTotalForNo, questions[questionID].isOver);
    }

    function getQuestionBetByAccount(uint questionID) public constant returns (string, string, uint, uint, uint, string, bool){
        return (questions[questionID].question,questions[questionID].answer,questions[questionID].betTotalForYes,questions[questionID].betTotalForNo, questions[questionID].speculators[msg.sender].bet, questions[questionID].speculators[msg.sender].answer, questions[questionID].isOver);
    }


    function getQuestionCount() public constant returns (uint){
        return (questionsCount);
    }

    function newQuestion(string question) returns (uint questionID, bool status, string log) {
       if (owned.owner !=  msg.sender) {
          status = false;
          QuestionAdded(0,question,false,'Sorry, only the owner of the contract can add questions.' );
       }
       else {
          // questionID is return variable
          questionID = questionsCount++;
          // Creates new struct and saves in storage. We leave out the mapping type.
          questions[questionID] = Question(questionID, question, "", false, 0, 0);
          // Set the status to true
          status = true;
          QuestionAdded(questionID,question,true,'Question has been added sucessfully.' );
       }
    }


    function answerQuestion(uint questionID, string answer) returns (bool status, string log ) {
       if (roleTrustedSource[msg.sender]==false) {
          status = false;
          log = 'Sorry, only the owner of the contract can answer the questions.';
       }
       else {
          // Check that the answer is Y or N
          questions[questionID].answer = answer;
          questions[questionID].isOver = true;
          // Set the status to true
          status = true;
          log = 'The answer has been updated.';
       }
       return (status, log);
     }

     function placeBet(uint questionID, bool answer) payable returns (bool status, string log ) {
        uint iBet =  msg.value;

        if ((questions[questionID].isOver == true) || (questions[questionID].speculators[msg.sender].bet > 0)) {
           status = false;
           log = 'Invalid Bet!';
           throw;
        }
        else {
           // At some point we want to mak sure we cater for changing bet
          questions[questionID].speculators[msg.sender].bet = iBet;

         if (answer == true) {
            questions[questionID].betTotalForYes = questions[questionID].betTotalForYes + iBet;
            questions[questionID].speculators[msg.sender].answer = "Yes";
          } else{
            questions[questionID].betTotalForNo = questions[questionID].betTotalForNo + iBet;
            questions[questionID].speculators[msg.sender].answer = "No";
          }

           // Set the status to true
           status = true;
           log = 'The answer has been updated.';
        }

        return (status, log);
    }

    function withdrawWinnings(uint questionID) payable returns (bool status, string log ) {
       status = false;
       uint initialBet;
       uint winnings;
       uint totalWinnings;

       if (questions[questionID].isOver != true) {
          log = 'The question has not been answered.  No withdrawal at this point!';
       }
       else {
          // Check that the user guessed correctly
          if (StringUtils.equal(questions[questionID].answer , questions[questionID].speculators[msg.sender].answer)){
             if (questions[questionID].speculators[msg.sender].bet > 0){
                 // Assign the winning to a variable
                 initialBet = questions[questionID].speculators[msg.sender].bet;
                 //set the bet to 0 to stop re-entrey
                 questions[questionID].speculators[msg.sender].bet = 0;
                 //Get the  winnings

                 if (StringUtils.equal(questions[questionID].speculators[msg.sender].answer, 'Yes')){
                    // Answer was a Yes.  Therefore split the No money
                    if (questions[questionID].betTotalForNo > 0) {
                       winnings = (initialBet / questions[questionID].betTotalForYes) * questions[questionID].betTotalForNo;
                       totalWinnings = initialBet + winnings;
                    } else{
                       // Get your money back
                       totalWinnings = initialBet;
                    }
                 } else{
                    // Answer was a No.  Therefore split the Yes money
                    if (questions[questionID].betTotalForYes > 0) {
                       winnings = (initialBet / questions[questionID].betTotalForNo) * questions[questionID].betTotalForYes;
                       totalWinnings = initialBet + winnings;
                    } else{
                       // Get your money back
                       totalWinnings = initialBet;
                    }
                 }

                 if (!msg.sender.send(totalWinnings)) {
                     // No need to call throw here, just reset the amount owing
                     questions[questionID].speculators[msg.sender].bet = initialBet;
                     status = false;
                     log = 'There are winning to be paid out.';
                 } else{
                     status = true;
                     log = 'There are winnings were paid out.';
                 }
             }else{
                status = true;
                log = 'You have already withdrawn your winnings.';
             }
          } else{  // You did not guess correctly
             // You have not won, but check that someone has won
             if ((questions[questionID].betTotalForYes == 0) || (questions[questionID].betTotalForNo == 0)){
                //No winners, so return bet
                initialBet = questions[questionID].speculators[msg.sender].bet;
                //set the bet to 0 to stop re-entrey
                questions[questionID].speculators[msg.sender].bet = 0;

                if (!msg.sender.send(initialBet)) {
                   // No need to call throw here, just reset the amount owing
                   questions[questionID].speculators[msg.sender].bet = initialBet;
                   status = false;
                   log = 'There are winning to be paid out.';
                } else{
                   status = true;
                   log = 'There are winnings were paid out.';
                }
             } else{
               // You have not win
               status = true;
               log = 'You did not win.';
             }
          }
         // Set the status to true
         return (status, log);
       }
    }



    function checkWinnings(uint questionID) public constant returns (bool status, uint winnings, string info ) {
       status = false;
       uint initialBet;
       uint totalWinnings;

       if (questions[questionID].isOver != true) {
          info = 'The question has not been answered.  No withdrawal at this point!';
          winnings = 0;
       }
       else {
          // Check that the user guessed correctly
          if (StringUtils.equal(questions[questionID].answer , questions[questionID].speculators[msg.sender].answer)){
             if (questions[questionID].speculators[msg.sender].bet > 0){
                 // Assign the winning to a variable
                 initialBet = questions[questionID].speculators[msg.sender].bet;

                 if (StringUtils.equal(questions[questionID].speculators[msg.sender].answer, 'Yes')){
                    // Answer was a Yes.  Therefore split the No money
                    if (questions[questionID].betTotalForNo > 0) {
                       winnings = (initialBet / questions[questionID].betTotalForYes) * questions[questionID].betTotalForNo;
                       totalWinnings = initialBet + winnings;
                    } else{
                       // Get your money back
                       totalWinnings = initialBet;
                    }
                 } else{
                    // Answer was a No.  Therefore split the Yes money
                    if (questions[questionID].betTotalForYes > 0) {
                       winnings = (initialBet / questions[questionID].betTotalForNo) * questions[questionID].betTotalForYes;
                       totalWinnings = initialBet + winnings;
                    } else{
                       // Get your money back
                       totalWinnings = initialBet;
                    }
                 }

                 winnings = totalWinnings;
                 info = 'You guessed correctly.';

             }else{
                status = true;
                info = 'You have already withdrawn your winnings.';
             }
          } else{  // You did not guess correctly
             // You have not won, but check that someone has won
             if ((questions[questionID].betTotalForYes == 0) || (questions[questionID].betTotalForNo == 0)){
                //No winners, so return bet
                initialBet = questions[questionID].speculators[msg.sender].bet;

                status = true;
                winnings = initialBet;
                info = 'You guessed incorrectly, but no one betted against you. Claim your initial bet';

             } else{
               // You have not win
               status = true;
               winnings = 0;
               info = 'You did not win.';
             }
          }
       }
    }

    function setUserRoleAdmin(address externalUser, bool roleFlag ) returns (bool status) {
     // Only the onwer of the contract can assign roles
     if ((owned.owner != msg.sender) || (externalUser == msg.sender))  {
        status = false;
     }
     else {
        // Set the external address's admin role flag
        roleAdmin[externalUser] = roleFlag;
        // Set the status to true
        status = true;
     }
    }

    function getUserRoleAdmin(address externalUser) public constant returns (bool isAdmin, bool status) {
     // Only the onwer of the contract can assign roles
     if (owned.owner != msg.sender)  {
        isAdmin = false;
        status = false;
     }
     else {
       // Get the external address's trusted source role flag
       if (owned.owner == externalUser){
         isAdmin = true;  // The owner is automatically a trusted source
       } else{
          isAdmin = roleAdmin[externalUser];
       }

       status = true;
     }
    }

    function setUserRoleTrustedSource(address externalUser, bool roleFlag ) returns (bool status) {
     // Only the onwer of the contract can assign roles
     if (owned.owner != msg.sender)  {
        status = false;
        throw;
     }
     else {
        // Set the external address's trusted source role flag
        roleTrustedSource[externalUser] = roleFlag;
        // Set the status to true
        status = true;
     }
    }

    function getUserRoleTrustedSource(address exAccount) public constant returns (bool isAdmin, bool status) {
      // Get the external address's trusted source role flag
      isAdmin = roleTrustedSource[exAccount];
      return (isAdmin, true);
    }


    function kill() {
      if (msg.sender == owner) suicide(owner);
    }

 }
