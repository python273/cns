const { expect } = require("chai");

describe("NameVickreyAuction", function() {
  let c;
  let ns;
  const NAME = 'hello-world';

  beforeEach(async () => {
    const NameSystem = await ethers.getContractFactory("CheapNameSystem");
    ns = await NameSystem.deploy();
    await ns.deployed();

    const NameVickreyAuction = await ethers.getContractFactory("NameVickreyAuction");
    c = await NameVickreyAuction.deploy(ns.address);
    await c.deployed();


    await ns.addOwner(c.address);
  })

  async function genHash(amount) {
    const nonce = ethers.utils.randomBytes(32);
    const response = await c.functions.getSaltedHash(amount, nonce);
    return [response[0], nonce];
  }

  it("Should start", async function() {
    const overrides = {
      value: ethers.utils.parseEther("1.0")
    };

    await c.start(NAME, overrides);
  });

  it("Should not start if already started", async function() {
    const overrides = {
      value: ethers.utils.parseEther("1.0")
    };
  
    await c.start(NAME, overrides);
    await expect(c.start(NAME, overrides)).to.be.revertedWith('Auction already exists.');
  });

  it("Should not start if taken", async function() {
    const [owner] = await ethers.getSigners();

    const overrides = {
      value: ethers.utils.parseEther("1.0")
    };
  
    await ns.register(NAME, owner.address);
    await expect(c.start(NAME, overrides)).to.be.revertedWith('Name is taken');
  });

  it("Should bid", async function() {
    const overrides = {
      value: ethers.utils.parseEther("10.0")
    };

    const [hash, nonce] = await genHash(ethers.utils.parseEther("5.0"));

    await c.start(NAME, overrides);
    await c.bid(NAME, hash, overrides);
  });

  it("Should reveal", async function() {
    const overrides = {
      value: ethers.utils.parseEther("10.0")
    };

    const amount = ethers.utils.parseEther("5.0");
    const [hash, nonce] = await genHash(amount);

    await c.start(NAME, overrides);
    await c.bid(NAME, hash, overrides);
    await network.provider.send("evm_increaseTime", [60 * 60 * 24 + 1]);
    await c.reveal(NAME, amount, nonce);
  });

  it("Should claim no bids", async function() {
    const [owner] = await ethers.getSigners();

    const overrides = {
      value: ethers.utils.parseEther("1.0")
    };

    await c.start(NAME, overrides);
    await network.provider.send("evm_increaseTime", [60 * 60 * 24 * 2 + 1]);

    expect((await ns.names(NAME)).owner).to.equal('0x0000000000000000000000000000000000000000');

    await c.claim(NAME);

    expect((await ns.names(NAME)).owner).to.equal(owner.address);
  });

  it("Should start if was not claimed", async function() {
    const [owner, addr1] = await ethers.getSigners();

    await c.start(NAME, { value: ethers.utils.parseEther("1.0") });
    await network.provider.send("evm_increaseTime", [60 * 60 * 24 * 3 + 1]);

    expect((await ns.names(NAME)).owner).to.equal('0x0000000000000000000000000000000000000000');

    await expect(c.claim(NAME)).to.be.revertedWith('Claim period already ended');

    await c.connect(addr1).start(NAME, { value: ethers.utils.parseEther("1.0") });
    await network.provider.send("evm_increaseTime", [60 * 60 * 24 * 2 + 1]);
    await c.connect(addr1).claim(NAME);

    expect((await ns.names(NAME)).owner).to.equal(addr1.address);
  });

  it("Should claim", async function() {
    const [owner] = await ethers.getSigners();

    const amount = ethers.utils.parseEther("5.0");
    const [hash, nonce] = await genHash(amount);

    await c.start(NAME, { value: ethers.utils.parseEther("1.0") });
    await c.bid(NAME, hash, { value: ethers.utils.parseEther("10.0") });
    await network.provider.send("evm_increaseTime", [60 * 60 * 24 + 1]);
    await c.reveal(NAME, amount, nonce);

    await network.provider.send("evm_increaseTime", [60 * 60 * 24 + 1]);

    await c.claim(NAME);

    expect((await ns.names(NAME)).owner).to.equal(owner.address);
  });

  it("Should not be able to claim twice", async function() {
    const [owner] = await ethers.getSigners();

    await c.start(NAME, { value: ethers.utils.parseEther("1.0") });
    await network.provider.send("evm_increaseTime", [60 * 60 * 24 * 2+ 1]);

    await c.claim(NAME);
    await expect(c.claim(NAME)).to.be.revertedWith('Already claimed');

    expect((await ns.names(NAME)).owner).to.equal(owner.address);
  });

  it("Should claim higher bid", async function() {
    const [owner, addr1] = await ethers.getSigners();

    const amount = ethers.utils.parseEther("5.0");
    const [hash, nonce] = await genHash(amount);

    await c.start(NAME, { value: ethers.utils.parseEther("1.0") });
    await c.connect(addr1).bid(NAME, hash, { value: ethers.utils.parseEther("10.0") });
    await network.provider.send("evm_increaseTime", [60 * 60 * 24 + 1]);
    await c.connect(addr1).reveal(NAME, amount, nonce);
    await network.provider.send("evm_increaseTime", [60 * 60 * 24 + 1]);

    expect((await ns.names(NAME)).owner).to.equal('0x0000000000000000000000000000000000000000');

    await c.connect(addr1).claim(NAME);

    expect((await ns.names(NAME)).owner).to.equal(addr1.address);

    expect(await c.balanceOf(addr1.address)).to.equal(ethers.utils.parseEther("9.0"));
  });

  it("Should claim 2 bids", async function() {
    const [owner, addr1, addr2] = await ethers.getSigners();

    await c.start(NAME, { value: ethers.utils.parseEther("1.0") });

    const amount1 = ethers.utils.parseEther("2.0");
    const [hash1, nonce1] = await genHash(amount1);
    await c.connect(addr1).bid(NAME, hash1, { value: ethers.utils.parseEther("20.0") });

    const amount2 = ethers.utils.parseEther("7.0");
    const [hash2, nonce2] = await genHash(amount2);
    await c.connect(addr2).bid(NAME, hash2, { value: ethers.utils.parseEther("10.0") });

    await network.provider.send("evm_increaseTime", [60 * 60 * 24 + 1]);
    await c.connect(addr2).reveal(NAME, amount2, nonce2);
    await c.connect(addr1).reveal(NAME, amount1, nonce1);
    await network.provider.send("evm_increaseTime", [60 * 60 * 24 + 1]);

    expect((await ns.names(NAME)).owner).to.equal('0x0000000000000000000000000000000000000000');

    await c.connect(addr2).claim(NAME);

    expect((await ns.names(NAME)).owner).to.equal(addr2.address);

    expect(await c.balanceOf(addr1.address)).to.equal(ethers.utils.parseEther("20.0"));
    expect(await c.balanceOf(addr2.address)).to.equal(ethers.utils.parseEther("8.0"));
    expect(await c.balanceOf(owner.address)).to.equal(ethers.utils.parseEther("3.0"));
  });

  it("Should not pass invalid name: empty", async function() {
    await expect(c.checkValid('')).to.be.revertedWith('Should not be empty')
  });

  it("Should not pass invalid name: starts with hyphen", async function() {
    await expect(c.checkValid('-hello')).to.be.revertedWith('Should not start or end with hyphen');
  });

  it("Should not pass invalid name: ends with hyphen", async function() {
    await expect(c.checkValid('hello-')).to.be.revertedWith('Should not start or end with hyphen');
  });

  it("Should not pass invalid name: letter after first zero byte", async function() {
    await expect(c.checkValid('hello\x00b')).to.be.revertedWith('Should contain only digits and lowercase letters');
  });
});
