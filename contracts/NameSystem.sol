//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

import "hardhat/console.sol";


abstract contract NameSystem {
  function urlTemplate() public virtual view returns (string memory);
  function urlRegistrar() public virtual view returns (string memory);
  function getOwner(string memory _name) public virtual view returns(address);
  function getRecords(string memory _name) public virtual view returns(string memory);
  function getSubNs(string memory _name) public virtual view returns(address);
}

contract HasOwners {
  mapping(address => bool) public owners;

  constructor() {
    owners[msg.sender] = true;
  }

  function addOwner(address _address) public onlyOwner {
    owners[_address] = true;
  }

  function removeOwner(address _address) public onlyOwner {
    owners[_address] = false;
  }

  modifier onlyOwner {
    require(
        owners[msg.sender],
        "Only owner can call this function."
    );
    _;
  }
}

contract CheapNameSystem is NameSystem, HasOwners {
  uint public expiresIn = 180 days;
  uint public renewalPeriod = 30 days;

  struct Name {
    address owner;
    string records;
    address subNs;
    uint expiresAt;
  }

  mapping(string => Name) public names;

  function urlTemplate() public override view returns(string memory) {
    return "https://%.cns.cheap/";
  }

  function urlRegistrar() public override view returns(string memory) {
    return "https://cns.cheap/";
  }

  function getOwner(string memory _name) public override view returns(address) {
    Name storage n = names[_name];
    if (block.timestamp < n.expiresAt) {
      return n.owner;
    }

    return address(0);
  }

  function getRecords(string memory _name) public override view returns(string memory) {
    return names[_name].records;
  }

  function getSubNs(string memory _name) public override view returns(address) {
    return names[_name].subNs;
  }

  function checkCanRegister(string memory _name) public view returns(bool) {
    Name storage n = names[_name];
    return (n.owner == address(0)) || (block.timestamp >= n.expiresAt);
  }

  function register(string memory _name, address _owner, uint _expiresAt) public onlyOwner {
    require(checkCanRegister(_name), "Already registered");

    if (_expiresAt == 0) {
      _expiresAt = block.timestamp + expiresIn;
    }

    Name storage n = names[_name];
    n.owner = _owner;
    n.expiresAt = _expiresAt;
  }

  function renew(string memory _name) public {
    Name storage n = names[_name];
    require(n.owner == msg.sender, "Not owner");

    uint currentExpiresAt = n.expiresAt;

    require(block.timestamp < currentExpiresAt, "Already expired");
    require(
      block.timestamp >= (currentExpiresAt - renewalPeriod),
      "Can not renew yet"
    );

    n.expiresAt = currentExpiresAt + expiresIn;
  }

  function transfer(string memory _name, address _newowner) public {
    Name storage n = names[_name];
    require(n.owner == msg.sender, "Not owner");

    n.owner = _newowner;
  }

  function updateRecords(string memory _name, string memory _records) public {
    Name storage n = names[_name];
    require(n.owner == msg.sender, "Not owner");

    n.records = _records;
  }
}
