// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.4;

contract Purchase {
    uint public value;
    address payable public seller;
    address payable public buyer;
    uint256 public confirmTime;
    uint256 public createTime;
    uint256 public completeTime;

    enum State { Created, Locked, Release, Inactive }
    // The state variable has a default value of the first member, `State.created`
    State public state;

    modifier condition(bool condition_) {
        require(condition_);
        _;
    }

    /// Only the seller can call this function.
    error OnlySeller();
    /// The function cannot be called at the current state.
    error InvalidState();
    /// The provided value has to be even.
    error ValueNotEven();
    // Only the buyer can call this function or time has elapsed
    error OnlyBuyerOrTimeElapsed();



    modifier onlySeller() {
        if (msg.sender != seller)
            revert OnlySeller();
        _;
    }

    modifier inState(State state_) {
        if (state != state_)
            revert InvalidState();
        _;
    }

    modifier onlyBuyerOrTimeElapsed(uint _time){
        if (msg.sender != buyer || (_time - confirmTime) <= 300)
            revert OnlyBuyerOrTimeElapsed();
        _;
    }

    event Aborted();
    event PurchaseConfirmed();
    event PurchaseCompleted();

    // Ensure that `msg.value` is an even number.
    // Division will truncate if it is an odd number.
    // Check via multiplication that it wasn't an odd number.
    constructor() payable {
        createTime = block.timestamp;
        seller = payable(msg.sender);
        value = msg.value / 2;
        if ((2 * value) != msg.value)
            revert ValueNotEven();
    }


    /// Abort the purchase and reclaim the ether.
    /// Can only be called by the seller before
    /// the contract is locked.
    function abort()
        external
        onlySeller
        inState(State.Created)
    {
        emit Aborted();
        state = State.Inactive;
        // We use transfer here directly. It is
        // reentrancy-safe, because it is the
        // last call in this function and we
        // already changed the state.
        seller.transfer(address(this).balance);
    }

    /// Confirm the purchase as buyer.
    /// Transaction has to include `2 * value` ether.
    /// The ether will be locked until confirmReceived
    /// is called.
    function confirmPurchase()
        external
        inState(State.Created)
        condition(msg.value == (2 * value))
        payable
    {
        emit PurchaseConfirmed();
        state = State.Locked;
        confirmTime = block.timestamp;
        buyer = payable(msg.sender);
    }

   
    /// This function refunds the seller, i.e.
    /// pays back the locked funds of the seller.
    /// Confirm that you (the buyer) received the item.
    /// This will release the locked ether.
    function completePurchase() 
        external 
        onlyBuyerOrTimeElapsed(block.timestamp) 
        inState(State.Locked)
    {
        emit PurchaseCompleted();
        state = State.Inactive;
        completeTime = block.timestamp;
        buyer.transfer(value);
        seller.transfer(3 * value);
    }
}
