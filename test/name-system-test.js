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
    await ns.register(NAME, owner.address);
    expect((await ns.names(NAME)).owner).to.equal(owner.address);
  });

  it("Should not re-register", async function() {
    await ns.register(NAME, owner.address);
    expect((await ns.names(NAME)).owner).to.equal(owner.address);

    await expect(
      ns.register(NAME, addr1.address)
    ).to.be.revertedWith("Already registered");
  });

  it("Should transfer", async function() {
    await ns.register(NAME, owner.address);
    await ns.transfer(NAME, addr1.address);

    expect((await ns.names(NAME)).owner).to.equal(addr1.address);
  });

  it("Should update data", async function() {
    const records = '[{"t":"TXT","d":"HELLO WORLD"}]';

    await ns.register(NAME, owner.address);
    await ns.updateRecords(NAME, records);

    expect((await ns.names(NAME)).records).to.equal(records);
  });

  it("Should not update someone else's data", async function() {
    const records = '[{"t":"TXT","d":"HELLO WORLD"}]';

    await ns.register(NAME, owner.address);
    await ns.updateRecords(NAME, records);

    await expect(
      ns.connect(addr1).updateRecords(NAME, records)
    ).to.be.revertedWith('Only owner can update records');

    expect(await ns.getRecords(NAME)).to.equal(records);
  });

});
