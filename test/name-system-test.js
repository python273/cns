const { expect } = require("chai");

describe("NameSystem", function() {
  const NAME = 'hello-world';

  let ns;
  let owner;
  let addr1;

  beforeEach(async () => {
    const NameSystem = await ethers.getContractFactory("CheapNameSystem");
    ns = await NameSystem.deploy();
    await ns.deployed();

    [owner, addr1] = await ethers.getSigners();
  })

  it("Should register", async function() {
    await ns.register(NAME, owner.address, 0);
    expect((await ns.names(NAME)).owner).to.equal(owner.address);
  });

  it("Should not re-register", async function() {
    await ns.register(NAME, owner.address, 0);

    await expect(
      ns.register(NAME, addr1.address, 0)
    ).to.be.revertedWith("Already registered");
  });

  it("Should transfer", async function() {
    await ns.register(NAME, owner.address, 0);
    await ns.transfer(NAME, addr1.address);

    expect((await ns.names(NAME)).owner).to.equal(addr1.address);
  });

  it("Should not transfer if not owner", async function() {
    await ns.register(NAME, owner.address, 0);

    await expect(
      ns.connect(addr1).transfer(NAME, addr1.address)
    ).to.be.revertedWith('Not owner');
  });

  it("Should renew", async function() {
    await ns.register(NAME, owner.address, 0);
    const expiresAt = (await ns.names(NAME)).expiresAt;
    await network.provider.send("evm_increaseTime", [60 * 60 * 24 * 150 + 1]);

    await ns.renew(NAME);

    const expiresAtAfterRenew = (await ns.names(NAME)).expiresAt;

    expect(expiresAtAfterRenew).to.equal(expiresAt.add(ethers.BigNumber.from(60 * 60 * 24 * 180)));
  });

  it("Should not immediately renew", async function() {
    await ns.register(NAME, owner.address, 0);

    await expect(
      ns.renew(NAME)
    ).to.be.revertedWith('Can not renew yet');
  });

  it("Should update data", async function() {
    const records = '[{"t":"TXT","d":"HELLO WORLD"}]';

    await ns.register(NAME, owner.address, 0);
    await ns.updateRecords(NAME, records);

    expect((await ns.names(NAME)).records).to.equal(records);
  });

  it("Should not update records if not owner", async function() {
    const records = '[{"t":"TXT","d":"HELLO WORLD"}]';

    await ns.register(NAME, owner.address, 0);
    await ns.updateRecords(NAME, records);

    await expect(
      ns.connect(addr1).updateRecords(NAME, records)
    ).to.be.revertedWith('Not owner');

    expect(await ns.getRecords(NAME)).to.equal(records);
  });

});
