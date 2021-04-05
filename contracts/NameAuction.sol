//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

import "./NameSystem.sol";


contract NameVickreyAuction {
    address owner;
    uint256 ownerBalance;
    CheapNameSystem public ns;

    constructor(CheapNameSystem _ns) {
        owner = msg.sender;
        ns = _ns;
    }

    function withdraw() public {
        require(msg.sender == owner);
        require(ownerBalance > 0);
        ownerBalance = 0;
        payable(owner).transfer(ownerBalance);
    }

    function checkValid(string memory _nameStr) public pure {
        // Validate name:
        // 0-9 a-z '-'
        // should not start or end with '-'

        bytes memory _name = bytes(_nameStr);
        require(_name.length >= 5, "Min length is 5");
        require(
            (_name[0] != '-') && (_name[_name.length - 1] != '-'),
            "Should not start or end with hyphen"
        );

        for (uint i = 0; i < _name.length; i++) {
            uint8 x = uint8(_name[i]);
            require(
                (x == 45) || (x >= 48 && x <= 57) || (x >= 97 && x <= 122),
                "Should contain only digits, lowercase letters and hyphens"
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

        mapping(address => uint256) bidAndBlindOf;
        mapping(address => bytes32) hashedBidOf;
        mapping(address => bool) revealed;
    }

    mapping(uint => Auction) public auctions;
    mapping(string => uint) public auctionIdForName;
    uint newAuctionId = 1;

    uint public biddingPeriod = 24 hours;
    uint public revelPeriod = 24 hours;
    uint public claimPeriod = 24 hours;
    uint public minBid = 1 ether;

    event Started(string indexed _name, uint _auctionId);
    event Bid(address indexed _by, uint256 indexed _newBidAndBlind, uint _auctionId);
    event Reveal(address indexed _by, uint256 indexed _amount, uint _auctionId);

    function start(string memory _name) public payable returns(uint) {
        require(msg.value >= minBid, "Min bid size is higher");
        checkValid(_name);

        uint _aid = auctionIdForName[_name];
        require(
            (_aid == 0) || auctions[_aid].claimEndsAt <= block.timestamp,
            "Already started"
        );

        uint auctionId = newAuctionId;
        newAuctionId += 1;
        Auction storage a = auctions[auctionId];
        auctionIdForName[_name] = auctionId;

        a.biddingEndsAt = block.timestamp + biddingPeriod;
        a.revealEndsAt = a.biddingEndsAt + revelPeriod;
        a.claimEndsAt = a.revealEndsAt + claimPeriod;
        a.highBidder = msg.sender;
        a.highBid = msg.value;
        a.secondBid = msg.value;
        a.bidAndBlindOf[msg.sender] = msg.value;

        ns.register(_name, address(this), a.claimEndsAt);

        emit Started(_name, auctionId);
        emit Bid(msg.sender, msg.value, auctionId);
        return auctionId;
    }

    function bid(string memory _name, bytes32 _hash) public payable {
        require(msg.value >= minBid, "Min bid size is higher");

        uint auctionId = auctionIdForName[_name];
        Auction storage a = auctions[auctionId];
        require(
            block.timestamp < a.biddingEndsAt,
            "Bidding period already ended"
        );

        a.bidAndBlindOf[msg.sender] += msg.value;
        a.hashedBidOf[msg.sender] = _hash;
        emit Bid(msg.sender, a.bidAndBlindOf[msg.sender], auctionId);
    }

    function claim(string memory _name) public {
        Auction storage a = auctions[auctionIdForName[_name]];
        require(msg.sender == a.highBidder, "Only high bidder can claim");
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

        uint256 bidAndBlind = a.bidAndBlindOf[a.highBidder];
        a.bidAndBlindOf[a.highBidder] = 0;
        payable(a.highBidder).transfer(bidAndBlind - a.secondBid);
        ownerBalance += a.secondBid;
        ns.renew(_name);
        ns.transfer(_name, a.highBidder);
    }

    function getSaltedHash(uint256 amount, bytes32 nonce) public view returns(bytes32) {
        return keccak256(abi.encodePacked(address(this), amount, nonce));
    }

    function reveal(string memory _name, uint256 amount, bytes32 nonce) public {
        uint auctionId = auctionIdForName[_name];
        Auction storage a = auctions[auctionId];

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

        uint256 bidAndBlind = a.bidAndBlindOf[msg.sender];

        emit Reveal(msg.sender, amount, auctionId);

        if (amount > bidAndBlind) {
            // if you bid more than you sent - you lose
            a.bidAndBlindOf[msg.sender] = 0;
            ownerBalance += bidAndBlind;
            return;
        }

        if (amount > a.highBid) {
            // undo the previous escrow
            if (a.highBidder != msg.sender) {
                // ignore auction start bid
                uint256 highBidderBidAndBlind = a.bidAndBlindOf[a.highBidder];
                a.bidAndBlindOf[a.highBidder] = 0;
                payable(a.highBidder).transfer(highBidderBidAndBlind);
            }

            a.secondBid = a.highBid;
            a.highBid = amount;
            a.highBidder = msg.sender;

            return;
        } else if (amount > a.secondBid) {
            a.secondBid = amount;
        }

        a.bidAndBlindOf[msg.sender] = 0;
        payable(msg.sender).transfer(bidAndBlind);
    }
}
