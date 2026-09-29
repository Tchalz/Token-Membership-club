// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "../src/MembershipClub.sol";

contract DeployMembershipClub is Script {
    function run() external returns (MembershipClub) {
        string memory baseTokenURI = vm.envOr("BASE_TOKEN_URI", string(""));

        vm.startBroadcast();
        MembershipClub club = new MembershipClub(baseTokenURI);
        vm.stopBroadcast();

        console2.log("MembershipClub deployed at:", address(club));
        return club;
    }
}