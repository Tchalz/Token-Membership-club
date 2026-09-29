// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/MembershipClub.sol";

contract MembershipClubTest is Test {
    MembershipClub club;

    address owner = address(this);
    address alice = address(0xA11CE);
    address bob = address(0xB0B);

    function setUp() public {
        club = new MembershipClub("ipfs://base-uri/");
        vm.deal(alice, 1 ether);
        vm.deal(bob, 1 ether);
    }

    // ---------- Deployment ----------

    function test_NameAndSymbol() public view {
        assertEq(club.name(), "Membership Club");
        assertEq(club.symbol(), "MEMBER");
    }

    function test_OwnerIsDeployer() public view {
        assertEq(club.owner(), owner);
    }

    function test_DefaultState() public view {
        assertEq(club.mintPrice(), 0.01 ether);
        assertEq(club.maxSupply(), 500);
        assertEq(club.nextTokenId(), 0);
    }

    // ---------- join() ----------

    function test_JoinMintsToken() public {
        vm.prank(alice);
        club.join{value: 0.01 ether}();

        assertTrue(club.isMember(alice));
        assertEq(club.ownerOf(0), alice);
        assertEq(club.nextTokenId(), 1);
    }

    function test_RevertWhen_InsufficientPayment() public {
        vm.prank(alice);
        vm.expectRevert("Not enough ETH sent");
        club.join{value: 0.005 ether}();
    }

    function test_RevertWhen_AlreadyMinted() public {
        vm.startPrank(alice);
        club.join{value: 0.01 ether}();
        vm.expectRevert("Already a member");
        club.join{value: 0.01 ether}();
        vm.stopPrank();
    }

    function test_CannotRemintAfterTransferringAway() public {
        vm.startPrank(alice);
        club.join{value: 0.01 ether}();
        club.transferFrom(alice, bob, 0);

        // alice no longer holds a token, but hasMinted still blocks a remint
        vm.expectRevert("Already a member");
        club.join{value: 0.01 ether}();
        vm.stopPrank();

        assertFalse(club.isMember(alice));
        assertTrue(club.isMember(bob));
    }

    function test_OverpaymentIsRefunded() public {
        uint256 balanceBefore = alice.balance;

        vm.prank(alice);
        club.join{value: 0.05 ether}();

        // spent exactly mintPrice, rest refunded
        assertEq(alice.balance, balanceBefore - club.mintPrice());
    }

    function test_NextTokenIdIncrements() public {
        vm.prank(alice);
        club.join{value: 0.01 ether}();
        assertEq(club.nextTokenId(), 1);

        vm.prank(bob);
        club.join{value: 0.01 ether}();
        assertEq(club.nextTokenId(), 2);
    }

    // ---------- isMember() ----------

    function test_IsMemberFalseByDefault() public view {
        assertFalse(club.isMember(alice));
    }

    // ---------- withdraw() ----------

    function test_WithdrawSendsBalanceToOwner() public {
        vm.prank(alice);
        club.join{value: 0.01 ether}();

        uint256 ownerBalanceBefore = owner.balance;
        club.withdraw();

        assertEq(owner.balance, ownerBalanceBefore + 0.01 ether);
        assertEq(address(club).balance, 0);
    }

    function test_RevertWhen_NonOwnerWithdraws() public {
        vm.prank(alice);
        vm.expectRevert();
        club.withdraw();
    }

    function test_RevertWhen_SoldOut() public {
        // set a low supply to test the cap without minting 500 times
        vm.prank(owner);
        club.setMaxSupply(1);

        vm.prank(alice);
        club.join{value: 0.01 ether}();

        vm.prank(bob);
        vm.expectRevert("Sold out");
        club.join{value: 0.01 ether}();
    }

    // ---------- setMintPrice() ----------

    function test_OwnerCanSetMintPrice() public {
        uint256 newPrice = 0.02 ether;
        club.setMintPrice(newPrice);
        assertEq(club.mintPrice(), newPrice);
    }

    function test_RevertWhen_NonOwnerSetsMintPrice() public {
        vm.prank(alice);
        vm.expectRevert();
        club.setMintPrice(0.02 ether);
    }

    function test_NewPriceEnforcedOnNextJoin() public {
        uint256 newPrice = 0.02 ether;
        club.setMintPrice(newPrice);

        vm.prank(alice);
        vm.expectRevert("Not enough ETH sent");
        club.join{value: 0.01 ether}();

        vm.prank(alice);
        club.join{value: newPrice}();
        assertTrue(club.isMember(alice));
    }

    // ---------- pause() / unpause() ----------

    function test_PauseBlocksJoin() public {
        club.pause();

        vm.prank(alice);
        vm.expectRevert();
        club.join{value: 0.01 ether}();

        club.unpause();

        vm.prank(alice);
        club.join{value: 0.01 ether}();
        assertTrue(club.isMember(alice));
    }

    receive() external payable {}
}
