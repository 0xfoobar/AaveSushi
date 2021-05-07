const { default: Web3 } = require("web3");

const AaveSushi = artifacts.require("AaveSushi");

contract('AaveSushi', (accounts) => {

    unlockedAccount = "0x4deB3EDD991Cfd2fCdAa6Dcfe5f1743F6E7d16A6";
    wethHolder = "0xC2942fa41Ed3Cfce4959610B6B265dBA99b933b5"; // 202 WETH
    wethAddress = "0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2";
    awethAddress = "0x030bA81f1c18d280636F32af80b9AAd02Cf0854e";
    aaveAddress = "0x7Fc66500c84A76Ad7e9c93437bFc5Ac33E2DDaE9";
    aaaveAddress = "0xba3D9687Cf50fE253cd2e1cFeEdE1d6787344Ed5"
    sushiAddress = "0xd9e1cE17f2641f24aE83637ab66a2cca9C378B9F";

    const erc20Abi = JSON.parse('[{"constant":true,"inputs":[],"name":"name","outputs":[{"name":"","type":"string"}],"payable":false,"stateMutability":"view","type":"function"},{"constant":false,"inputs":[{"name":"guy","type":"address"},{"name":"wad","type":"uint256"}],"name":"approve","outputs":[{"name":"","type":"bool"}],"payable":false,"stateMutability":"nonpayable","type":"function"},{"constant":true,"inputs":[],"name":"totalSupply","outputs":[{"name":"","type":"uint256"}],"payable":false,"stateMutability":"view","type":"function"},{"constant":false,"inputs":[{"name":"src","type":"address"},{"name":"dst","type":"address"},{"name":"wad","type":"uint256"}],"name":"transferFrom","outputs":[{"name":"","type":"bool"}],"payable":false,"stateMutability":"nonpayable","type":"function"},{"constant":false,"inputs":[{"name":"wad","type":"uint256"}],"name":"withdraw","outputs":[],"payable":false,"stateMutability":"nonpayable","type":"function"},{"constant":true,"inputs":[],"name":"decimals","outputs":[{"name":"","type":"uint8"}],"payable":false,"stateMutability":"view","type":"function"},{"constant":true,"inputs":[{"name":"","type":"address"}],"name":"balanceOf","outputs":[{"name":"","type":"uint256"}],"payable":false,"stateMutability":"view","type":"function"},{"constant":true,"inputs":[],"name":"symbol","outputs":[{"name":"","type":"string"}],"payable":false,"stateMutability":"view","type":"function"},{"constant":false,"inputs":[{"name":"dst","type":"address"},{"name":"wad","type":"uint256"}],"name":"transfer","outputs":[{"name":"","type":"bool"}],"payable":false,"stateMutability":"nonpayable","type":"function"},{"constant":false,"inputs":[],"name":"deposit","outputs":[],"payable":true,"stateMutability":"payable","type":"function"},{"constant":true,"inputs":[{"name":"","type":"address"},{"name":"","type":"address"}],"name":"allowance","outputs":[{"name":"","type":"uint256"}],"payable":false,"stateMutability":"view","type":"function"},{"payable":true,"stateMutability":"payable","type":"fallback"},{"anonymous":false,"inputs":[{"indexed":true,"name":"src","type":"address"},{"indexed":true,"name":"guy","type":"address"},{"indexed":false,"name":"wad","type":"uint256"}],"name":"Approval","type":"event"},{"anonymous":false,"inputs":[{"indexed":true,"name":"src","type":"address"},{"indexed":true,"name":"dst","type":"address"},{"indexed":false,"name":"wad","type":"uint256"}],"name":"Transfer","type":"event"},{"anonymous":false,"inputs":[{"indexed":true,"name":"dst","type":"address"},{"indexed":false,"name":"wad","type":"uint256"}],"name":"Deposit","type":"event"},{"anonymous":false,"inputs":[{"indexed":true,"name":"src","type":"address"},{"indexed":false,"name":"wad","type":"uint256"}],"name":"Withdrawal","type":"event"}]');

    const weth = new web3.eth.Contract(erc20Abi, wethAddress);
    const aweth = new web3.eth.Contract(erc20Abi, awethAddress);
    const aave = new web3.eth.Contract(erc20Abi, aaveAddress);
    const aaave = new web3.eth.Contract(erc20Abi, aaaveAddress);

    const ether = 1000000000000000000;

    async function printState() {
        wethBalance = web3.utils.fromWei(await weth.methods.balanceOf(unlockedAccount).call(), "ether");
        aaveBalance = web3.utils.fromWei(await aave.methods.balanceOf(unlockedAccount).call(), "ether");
        awethBalance = web3.utils.fromWei(await aweth.methods.balanceOf(unlockedAccount).call(), "ether");
        aaaveBalance = web3.utils.fromWei(await aaave.methods.balanceOf(unlockedAccount).call(), "ether");
        console.log(wethBalance);
        console.log(aaveBalance);
        console.log(awethBalance);
        console.log(aaaveBalance);
    }

    it("should call flashloan", async () => {
        const instance = await AaveSushi.deployed();

        let awethBalance;
        let aaaveBalance;
        let loanAmount;
        let amountInExact;
        let amountOutMin = 1;
        let tx;

        await printState();

        loanAmount = 1000;
        amountInExact = 1000;

        loanAmount = 1000000000000000;
        loanAmount = "1000000000000000"; // 15 zeroes
        loanAmount = "1000000000000000000"; // 18 zeroes; 1 eth
        // loanAmount = "9000000000000000000"; // 18 zeroes, 199 eth
        // loanAmount = "1000000000000000000000"; // Fails bc account doesn't have this much
        // loanAmount = "100401858857524954751512";

        loanPlusPremium = "2000000000000000000";

        tx = await aweth.methods.approve(instance.contract._address, loanPlusPremium).send({
            "from": unlockedAccount
        });
        console.log("Approved aWETH for AaveSushi");

        // tx = await instance.contract.methods.swapCollateral(
        //     wethAddress,
        //     aaveAddress,
        //     loanAmount,
        //     amountInExact,
        //     amountOutMin
        // ).send({
        //     "from": unlockedAccount,
        //     "gasLimit": 5000000
        // });
        // console.log("Called swapCollateral");

        // Simulate a flashloan with no premium
        tx = await weth.methods.approve(sushiAddress, amountInExact).send({
            "from": unlockedAccount
        });
        console.log("Approved WETH for sushiRouter");

        // Then call the flashloan callback
        tx = await weth.methods.transfer(instance.contract._address, loanAmount).send({
            "from": wethHolder,
        });
        console.log("Transferred WETH to contract address");

        let assets = [wethAddress];
        let amounts = [loanAmount];
        let premiums = [0];

        console.log(`assets: ${assets}`);
        console.log(`amounts: ${amounts}`);
        console.log(`premiums: ${premiums}`);
        tx = await instance.contract.methods.executeOperation(
            assets,
            amounts,
            premiums,
            unlockedAccount,
            "0x"
        ).send({
            "from": unlockedAccount,
            "gasLimit": 5000000
        });
        console.log("Called executeOperation");

        await printState();

    });

});