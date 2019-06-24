/**
*@copyright yangminghai  yomohoo@gmail.com
*锁仓合约大概流程
*1.发布ERC20 Token智能合约
*2.配置锁仓合约参数，发布锁仓的智能合约
*3.把要锁仓的ERC20代币转入锁仓智能合约
**
*备注：由于有些仓促，难免会存在某些设计缺陷，比如解仓条件之类，
*请谨慎引用，理解锁仓原理，并根据自己的需求重新设计
*
*/
pragma solidity >=0.4.26 <0.7;
import "./Ownable.sol";
import "./ERC20Interface.sol";
import "./libs/math/SafeMath.sol";

contract VestToken is Ownable{
    using SafeMath for uint256;
    //受益人结构体
    struct Beneficiary{
        address addr;  //受益人地址
        uint256 lockTokens;  //锁仓token数量
        uint256 unlockTokens; //解锁的token数量
        bool revoked;          //是否已撤销
        bool revocable;         //是否可撤销
        /**解锁条件 根据需要自己调整,常用时间作为解锁条件*/
        uint256 credits; //每次授信额度与token对应1:1
    }

    //address(this)的余额 = totalLockTokens - totalUnLockTokens;
    uint256 public totalLockTokens;    //已经锁仓的Token总量
    uint256 public totalUnlockTokens;  //已经解锁的token总量

    //锁仓人员
    mapping(address=>Beneficiary) beneficiaries;
    //token对象
    ERC20Interface token;

    //事件
    /**
    *锁仓事件
    *锁仓人，金额，是否可撤销
    */
    event EventLockTokens(address indexed addr,uint256 indexed lockTokens,bool revocable);
    /*
    *解锁token事件，受益人地址，解锁tokens
    */
    event EventUnlockTokens(address indexed addr,uint256 indexed unlockTokens);
    /*
    *撤销锁仓事件  被锁仓者
    */
    event EventRevoked(address indexed addr);


        constructor(address tokenAddr) public {
            token = ERC20Interface(tokenAddr);
            totalLockTokens = 0;
            totalUnlockTokens = 0;
        }

    // function setupTokenAddr(address addr) public onlyOwner{
    //      token = ERC20Interface(addr);
    // }
    /**
    *添加锁仓受益人
    *受益人地址，锁仓金额，是否可撤销
    */
    function increaseLockTokens(address addr,uint256 lockTokens,bool revocable) public onlyOwner {
        require(addr != address(0),"锁仓地址不能为空");
        require(lockTokens > 0,"锁仓金额必须大于0");
        require(beneficiaries[addr].addr == address(0),"该地址已经有锁仓");
        uint256 totalTokens = token.balanceOf(address(this));
        require(totalTokens > totalLockTokens.add(lockTokens).sub(totalUnlockTokens),"余额不足够锁仓了"); //该地址的余额要大于正在锁仓数量
        beneficiaries[addr] = Beneficiary({
            addr:addr,
            lockTokens:lockTokens,
            unlockTokens:0,
            revoked:false,
            revocable:revocable,
            credits:0
        });
        totalLockTokens = totalLockTokens.add(lockTokens);
        emit EventLockTokens(addr,lockTokens,revocable);
    }

    function balanceOf(address addr) view public returns(uint256) {
        return token.balanceOf(address(addr));
    }

    /**
    *触发锁仓条件进行解仓
    *addr 锁仓人信息
    *_credits 授信积分 在此为1:1兑换代币
    */
    function unlockTokensByCredits(address addr,uint _credits) public onlyOwner {
        require(addr != address(0),"锁仓人地址不能为空");
        Beneficiary storage beneficiary = beneficiaries[addr];
        require(beneficiary.revoked==false,"该地址已被撤销锁仓");
        require(beneficiary.unlockTokens.add(_credits) <= beneficiary.lockTokens,"剩余锁仓额度不足!");
        beneficiary.unlockTokens = beneficiary.unlockTokens.add(_credits); //受益人已解仓数量
        require(token.transfer(addr,_credits),"解仓转账返回失败 ");
        totalUnlockTokens = totalUnlockTokens.add(_credits); //已解仓总数
        emit EventUnlockTokens(addr,_credits);
    }

    /**
    *返回锁仓人(受益人)的信息
    *
    *_addr 锁仓人地址
    */
    function beneficiaryInfo(address _addr) view public returns(address addr,uint256 lockTokens,uint256 unLockTokens,bool revoked, bool revocable) {
       Beneficiary storage beneficiary = beneficiaries[_addr];
       addr = beneficiary.addr;
       lockTokens = beneficiary.lockTokens;
       unLockTokens = beneficiary.unlockTokens;
       revocable = beneficiary.revocable;
       revoked = beneficiary.revoked;
    }

    /*
    *撤销锁仓,前提是可以撤销
    */
    function revokedLockTokens(address _addr) public onlyOwner {
         Beneficiary storage beneficiary = beneficiaries[_addr];
         require(beneficiary.revocable==true,"该仓不可撤销");
         require(beneficiary.revoked==false,"该仓已经撤销过了");
         //解锁
         unlockTokensByCredits(_addr,beneficiary.lockTokens.sub(beneficiary.unlockTokens));
          beneficiary.revoked = true;
         emit EventRevoked(_addr);
    }

}