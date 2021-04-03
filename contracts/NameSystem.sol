//SPDX-License-Identifier: Unlicense
pragma solidity ^0.7.0;

import "hardhat/console.sol";


abstract contract NameSystem {
  function urlTemplate() public virtual view returns (string memory);
  function urlRegistrar() public virtual view returns (string memory);
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

  struct NameInfo {
    address owner;
    string records;
    address subNs;
    uint expiresAt;
  }

  mapping(string => NameInfo) public names;

  function urlTemplate() public override view returns(string memory) {
    return "https://%.cns.cheap/";
  }

  function urlRegistrar() public override view returns(string memory) {
    return "https://cns.cheap/";
  }

  function getRecords(string memory _name) public override view returns(string memory) {
    return names[_name].records;
  }

  function getSubNs(string memory _name) public override view returns(address) {
    return names[_name].subNs;
  }

  function checkCanRegister(string memory _name) public view returns(bool) {
    NameInfo storage n = names[_name];
    return (n.owner == address(0)) || (block.timestamp >= n.expiresAt);
  }

  function register(string memory _name, address _owner) public onlyOwner {
    require(checkCanRegister(_name), "Already registered");

    names[_name].owner = _owner;
    names[_name].expiresAt = block.timestamp + expiresIn;
  }

  function renew(string memory _name, address _newowner) public {
    NameInfo storage n = names[_name];
    require(n.owner == msg.sender, "Only owner can renew");
    uint currentExpiresAt = names[_name].expiresAt;
    require(block.timestamp >= currentExpiresAt, "Already expired");
    require(
      block.timestamp > (currentExpiresAt - renewalPeriod),
      "Can renew only X days before expiration"
    );

    names[_name].expiresAt = currentExpiresAt + expiresIn;
  }

  function transfer(string memory _name, address _newowner) public {
    NameInfo storage n = names[_name];
    require(n.owner == msg.sender, "Only owner can transfer");

    names[_name].owner = _newowner;
  }

  function updateRecords(string memory _name, string memory _records) public {
    NameInfo storage n = names[_name];
    require(n.owner == msg.sender, "Only owner can update records");

    names[_name].records = _records;
  }
}
