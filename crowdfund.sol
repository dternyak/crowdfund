pragma solidity ^0.4.17;
    import "github.com/OpenZeppelin/openzeppelin-solidity/contracts/math/SafeMath.sol";


contract Escrow {

    using SafeMath for uint256;

    // state
    uint public raiseGoal;
    uint public currentFunds;
    address receipient;
    mapping(address => uint) private contributions;
    mapping(address => uint) private proportionalCurContribution;

    address[] private contributors;
    address[] public refundVoters; 

    constructor(uint raiseGoalAmount) public {
        raiseGoal = raiseGoalAmount;
        currentFunds = 0;
    }

    function contributionStaysUnderRaiseGoal(uint amount) private view returns (bool) {
        require((amount.add(currentFunds)) <= raiseGoal, "Sorry! This contribution exceeds the raise goal.");
        return true;
    }

    function () public payable {
        if (contributionStaysUnderRaiseGoal(msg.value)) {
            contributors.push(msg.sender);
            if (contributions[msg.sender] > 0) {
                contributions[msg.sender] += msg.value;
            } else {
                contributions[msg.sender] = msg.value;
            }
            currentFunds += msg.value;
        }
    }

    function voteRefund() public onlyContributor {
        refundVoters.push(msg.sender);
    }

    function isMajorityVotingToRefund() public view returns (bool) {
        uint valueVotingToRefund = 0;
        for (uint i = 0; i < refundVoters.length; i++) {
            valueVotingToRefund += contributions[refundVoters[i]];
            }
        return valueVotingToRefund.mul(2) > currentFunds;
    }
    
    function fundtransfer(address etherreceiver, uint256 amount) private {
        if(!etherreceiver.send(amount)){
           revert();
        }    
    }
    
    function getRaiseGoal() public view returns(uint){
        return raiseGoal;
    }
    
    function buildProportionalContributions() private {
        for (uint i = 0; i < contributors.length; i++) {
            uint originalContributionAmount = contributions[contributors[i]];
            proportionalCurContribution[contributors[i]] = originalContributionAmount.mul(currentFunds).div(raiseGoal);
        }
    }


    function refundRemainingProportionally()  private {
        buildProportionalContributions();
        for (uint i = 0; i < contributors.length; i++) {
            fundtransfer(contributors[i], proportionalCurContribution[contributors[i]]);
        }
    }

    function refund() public {
        require(isMajorityVotingToRefund(), "Majority is not voting to refund");
        refundRemainingProportionally();
    }
    
    function isCallerContributor() public view returns (bool) {
        bool addressFound = false;
        for (uint i = 0; i < contributors.length; i++) {
            if (msg.sender == contributors[i]) {
                addressFound = true;
                break;
            }
        }
        return addressFound;
    }

    modifier onlyContributor() {
        bool isContributor = isCallerContributor();
        if (isContributor) {
            _;
        } else {
            revert("Caller is not a contributor");
        }
    }
   
}



