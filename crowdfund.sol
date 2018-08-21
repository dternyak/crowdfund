// TODO 
// 1. Allow re-tries for milestone payout requests
pragma solidity ^0.4.24;
import "openzeppelin-solidity/contracts/math/SafeMath.sol";


contract Escrow {

    using SafeMath for uint256;

    struct Milestone {
        uint amount;
        address[] noVoters;
        uint payoutRequestVoteDeadline;
        bool paid;
    }

    // state

    // stored in minutes;
    uint public milestoneVotingPeriod;
    // stored in minutes
    uint public deadline;
    // goal in Wei
    uint public raiseGoal;
    address public beneficiary;
    // contributions are disabled if the contract has been refunded
    bool public isArchived;
    bool public isRaiseGoalReached;
    // authorized addresses to ask for milestone payouts
    // constructor ensures that all values combined equal raiseGoal

    mapping(address => uint) public contributions;
    mapping(address => uint) public proportionalContribution;

    address[] public contributors;
    address[] public refundVoters;
    address[] public trustees;
    Milestone[] public milestones;

    constructor(
        uint raiseGoalAmount, 
        address payOutAddress, 
        address[] trusteesAddresses, 
        uint[] allMilestones,
        uint durationInMinutes,
        uint milestoneVotingPeriodInMinutes) 
    public {
        // ensure that cumalative milestone payouts equal raiseGoalAmount
        // implicitly ensure that there is at least one milestone stage per escrow
        uint memory milestoneTotal = 0;
        for (uint i = 0; i < allMilestones.length; i++) {
            milestoneTotal += allMilestones[i];
            milestones.push(Milestone({
                amount: allMilestones[i],
                noVoters: [],
                paid: false
            }));
        }
        require((milestoneTotal == raiseGoalAmount), "milestone total must equal raise goal");

        raiseGoal = raiseGoalAmount;
        beneficiary = payOutAddress;
        trustees = trusteesAddresses;
        deadline = now + durationInMinutes * 1 minutes;
        milestoneVotingPeriod = milestoneVotingPeriodInMinutes * 1 minutes;
    }

    function payMilestonePayout(uint index) public {
        if (milestones[i].payoutRequestVoteDeadline >= now) {
            if (!isMajorityVoting(milestones[i].noVoters)) {
                fundTransfer(beneficiary, milestones[i].amount);
            }
        }
    }

    function voteNoMilestonePayout(uint index) public onlyContributor {
        milestones[i].noVoters.push(msg.sender);
    }

    function requestMilestonePayout (uint index) public onlyTrustee {
        bool memory lowestIndexPaid;
        for (uint i = 0; i < milestones.length; i++) {
            if (milestones[i].paid) {
                lowestIndexUnpaid = i;
            }
        }
        // prevent requesting paid milestones
        if (milestones[index].paid) {
            revert("Milestone already paid");
        }
        // prevent requesting future milestones
        if (index != lowestIndexPaid) {
            revert("Earlier milestone has not yet been paid");
        }

        if (!milestones[i].payoutRequestVoteDeadline) {
            milestones[i].payoutRequestVoteDeadline = now + milestoneVotingPeriod;
        } else {
            revert("Milestone payment request has already been set.");
        }
    }

    function () public payable onlyOnGoing {
        require((msg.value.add(address(this).balance)) <= raiseGoal, "Sorry! This contribution exceeds the raise goal.");
        contributors.push(msg.sender);
        if (contributions[msg.sender] > 0) {
            contributions[msg.sender] += msg.value;
        } else {
            contributions[msg.sender] = msg.value;
        }
        if (msg.value.add(address(this).balance) == raiseGoal) {
            isRaiseGoalReached = true;
        }
    }
    
    function voteRefund() public onlyContributor onlyReached {
        refundVoters.push(msg.sender);
    }

    function fundTransfer(address etherReceiver, uint256 amount) private {
        if(!etherReceiver.send(amount)){
            revert();
        }
    }

    function buildProportionalContributions() private {
        for (uint i = 0; i < contributors.length; i++) {
            uint originalContributionAmount = contributions[contributors[i]];
            proportionalContribution[contributors[i]] = originalContributionAmount.mul(address(this).balance).div(raiseGoal);
        }
    }

    function refundRemainingProportionally() private {
        buildProportionalContributions();
        for (uint i = 0; i < contributors.length; i++) {
            fundTransfer(contributors[i], proportionalContribution[contributors[i]]);
        }
    }

    function refundWhenFailed() public {
        if (isFailed()) {
            refundRemainingProportionally();
        }
    }

    function refund() public onlyReached {
        if (isMajorityVoting(refundVoters)) {
            refundRemainingProportionally();
        }
    }

    function isMajorityVoting(address[] voters) public view returns (bool) {
        uint memory valueVoting = 0;
        for (uint i = 0; i < voters.length; i++) {
            valueVoting += contributions[voters[i]];
        }
        return valueVoting.mul(2) > address(this).balance;
    }

    function isCallerInAddressArray(address[] addressArray) public view returns (bool) {
        for (uint i = 0; i < addressArray.length; i++) {
            if (msg.sender == addressArray[i]) {
                return true;
            }
        }
        return false;
    }

    function isFailed() public view {
        return (now >= deadline) && !isRaiseGoalReached;
    }

    modifier onlyReached() {
        if (isRaiseGoalReached) _;
    }
    
    modifier onlyOnGoing() {
        if ((now <= deadline) && !isRaiseGoalReached) _;
    }

    modifier onlyContributor() {
        if (isCallerInAddressArray(contributors)) _;
    }

    modifier onlyTrustee() {
        if (isCallerInAddressArray(trustees)) _;
    }

}
