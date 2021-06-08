// SPDX-License-Identifier: MIT
pragma solidity >=0.4.21 <0.7.0;

contract MultiSigWallet{
    address[] public owners;
    uint public countForConsensus;
    mapping (address=>bool) isOwner;
    
    struct Transaction{
        address requester;
        address to;
        uint requestID;
        uint value;
        bytes data;
        uint confirmationCount;
        bool executed;
        mapping( address=>bool) isApproved;
    }

    Transaction[] public transactions;
    //Events
    event RequestRaised(address whoRaised,uint amount,uint requestID);
    event RequestExecuted(uint requestID);
    event RequestApproved(uint requestID,address approver);
    event RevokeApproval(uint requestID,address revoker);
    event AmountDeposited(address sender,uint value);

    // receive() external payable {}

    // fallback() external payable {}
//["0x5B38Da6a701c568545dCfcB03FcB875f56beddC4","0xAb8483F64d9C6d1EcF9b849Ae677dD3315835cb2"]
    constructor (address[] memory _owners,uint _countForConsensus) public {
        require(_owners.length>0,"You should supply some owners");
        require(_countForConsensus>0 ,"Consensus count should be >0");
        require(_countForConsensus <= _owners.length,"Consensus count should be less than or equal to the number of owners");
        for (uint256 index = 0; index < _owners.length; index++) {
            address temp = _owners[index];
            require(!isOwner[temp],"Not a unique owner");
            isOwner[temp] = true;
            owners.push(temp);
        }
        countForConsensus = _countForConsensus;
    }

    modifier onlyOwner() {
        require(isOwner[msg.sender],"Not an owner");
        _;
    }

    modifier requestExists(uint _txIndex) {
        require(_txIndex<transactions.length,"The transaction doesn't exists!");
        _;
    }

    modifier requestExecuted(uint _txIndex){
        require(!transactions[_txIndex].executed,"Request already executed");
        _;
    }
    function deposit () external payable{
        emit AmountDeposited(msg.sender, msg.value);
    }
    function raiseRequest(uint amount,address _to) public onlyOwner{
        transactions.push(Transaction({
            requester : msg.sender,
            to:_to,
            data : msg.data,
            value : amount,
            requestID : transactions.length,
            confirmationCount:1,
            executed:false
        }));
        
        emit RequestRaised(msg.sender, amount, transactions.length -1);
    }

    function executeRequest(uint _requestID) public onlyOwner requestExists(_requestID) requestExecuted(_requestID){
        require(transactions[_requestID].requester==msg.sender,"Only the requester can execute this transaction");
        require(transactions[_requestID].confirmationCount>=countForConsensus,"There are not enough confirmation");
        Transaction memory temp = transactions[_requestID];

        (bool success,) = temp.to.call{value:temp.value}("");
        require(success,"Transaction failed");
        transactions[_requestID].executed = true;
        emit RequestExecuted(_requestID);
    }
 
    function approveRequest(uint _requestID) public onlyOwner requestExists(_requestID) requestExecuted(_requestID){
        require(!transactions[_requestID].isApproved[msg.sender],"You have already approved the request!");

        transactions[_requestID].confirmationCount+=1;
        transactions[_requestID].isApproved[msg.sender]=true;
        emit RequestApproved(_requestID, msg.sender);
    }

    function revokeApproval(uint _requestID) public onlyOwner requestExists(_requestID) requestExecuted(_requestID){
        
        require(transactions[_requestID].isApproved[msg.sender],"You have not approved the request yet!");

        transactions[_requestID].isApproved[msg.sender] = false;
        transactions[_requestID].confirmationCount -=1;
        emit RevokeApproval(_requestID, msg.sender);
    }
}
