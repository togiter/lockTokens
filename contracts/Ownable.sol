pragma solidity >=0.4.26 <0.6;
contract Ownable{
    address owner;
    event OwnershipTransferred(address indexed preOwner,address indexed newOwner);
    constructor() public{
        owner = msg.sender;
    }

    modifier onlyOwner(){
        require(msg.sender == owner,"it is not owner call");
        _;
    }

    function transferOwnership(address newOwner) public onlyOwner {
        require(newOwner != address(0),"not owner called");
        emit OwnershipTransferred(owner,newOwner);
        owner = newOwner;
    }
}