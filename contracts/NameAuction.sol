//SPDX-License-Identifier: Unlicense
pragma solidity ^0.7.0;

import "./NameSystem.sol";


contract NameVickreyAuction {
    address owner;
    CheapNameSystem public ns;

    constructor(CheapNameSystem _ns) {
        owner = msg.sender;
        ns = _ns;
    }

    function checkValid(string memory _nameStr) public pure {
        // Validate name:
        // 0-9 a-z '-'
        // should not start or end with '-'

        bytes memory _name = bytes(_nameStr);
        require(_name.length > 0, "Should not be empty");
        require(
            (_name[0] != '-') && (_name[_name.length - 1] != '-'),
            "Should not start or end with hyphen"
        );

        for (uint i = 0; i < _name.length; i++) {
            uint8 x = uint8(_name[i]);
            require(
                (x == 45) || (x >= 48 && x <= 57) || (x >= 97 && x <= 122),
                "Should contain only digits and lowercase letters"
            );
        }
    }

    struct Auction {
        uint biddingEndsAt;
        uint revealEndsAt;
        uint claimEndsAt;
        bool claimed;

        address highBidder;
        uint256 highBid;
        uint256 secondBid;

        mapping(address => bytes32) hashedBidOf;
        mapping(address => bool) revealed;
    }

    mapping(uint => Auction) public auctions;
    mapping(string => uint) public auctionIdForName;
    uint newAuctionId = 1;

    mapping(address => uint256) public balanceOf;

    uint public biddingPeriod = 24 hours;
    uint public revelPeriod = 24 hours;
    uint public claimPeriod = 24 hours;
    uint public minBid = 1 ether;

    function start(string memory _name) public payable {
        require(msg.value >= minBid, "Min bid size is higher");
        checkValid(_name);

        uint _aid = auctionIdForName[_name];
        require(
            (_aid == 0) || auctions[_aid].claimEndsAt <= block.timestamp,
            "Auction already exists."
        );

        require(ns.checkCanRegister(_name), "Name is taken");

        Auction storage a = auctions[newAuctionId];
        auctionIdForName[_name] = newAuctionId;
        newAuctionId += 1;

        a.biddingEndsAt = block.timestamp + biddingPeriod;
        a.revealEndsAt = a.biddingEndsAt + revelPeriod;
        a.claimEndsAt = a.revealEndsAt + claimPeriod;
        a.highBidder = msg.sender;
        a.highBid = msg.value;
        a.secondBid = msg.value;
    }

    function bid(string memory _name, bytes32 _hash) public payable {
        require(msg.value >= minBid, "Min bid size is higher");

        Auction storage a = auctions[auctionIdForName[_name]];
        require(
            block.timestamp < a.biddingEndsAt,
            "Bidding period already ended"
        );

        a.hashedBidOf[msg.sender] = _hash;
        balanceOf[msg.sender] += msg.value;
    }

    function claim(string memory _name) public {
        Auction storage a = auctions[auctionIdForName[_name]];
        require(msg.sender == a.highBidder, "Only high bidded can claim");
        require(a.claimed == false, "Already claimed");
        require(
            block.timestamp >= a.revealEndsAt,
            "Wait until reveal period ends"
        );
        require(
            block.timestamp < a.claimEndsAt,
            "Claim period already ended"
        );

        a.claimed = true;
        balanceOf[msg.sender] += a.highBid - a.secondBid;
        balanceOf[owner] += a.secondBid;
        ns.register(_name, msg.sender);
    }

    function getSaltedHash(uint256 amount, bytes32 nonce) public view returns(bytes32) {
        return keccak256(abi.encodePacked(address(this), amount, nonce));
    }

    function reveal(string memory _name, uint256 amount, bytes32 nonce) public {
        Auction storage a = auctions[auctionIdForName[_name]];

        require(
            block.timestamp >= a.biddingEndsAt,
            "Wait until reveal period starts"
        );
        require(
            block.timestamp < a.revealEndsAt,
            "Reveal period already ended"
        );

        require(getSaltedHash(amount, nonce) == a.hashedBidOf[msg.sender]);

        require(!a.revealed[msg.sender]);
        a.revealed[msg.sender] = true;

        if (amount > balanceOf[msg.sender]) {
            return;
        }

        if (amount > a.highBid) {
            // undo the previous escrow
            balanceOf[a.highBidder] += a.highBid;

            a.secondBid = a.highBid;
            a.highBid = amount;
            a.highBidder = msg.sender;

            // escrow an amount equal to the _highest_ bid
            // not second, because if second is updated later
            // but balance was withdrawn
            // there will be not enough funds to claim
            balanceOf[a.highBidder] -= a.highBid;
        } else if (amount > a.secondBid) {
            a.secondBid = amount;
        }
    }

    function withdraw() public {
        uint256 amount = balanceOf[msg.sender];
        require(amount > 0, "No balance");
        balanceOf[msg.sender] = 0;
        msg.sender.transfer(amount);
    }
}
