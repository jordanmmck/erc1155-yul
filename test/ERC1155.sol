// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import "forge-std/Test.sol";
import "./lib/YulDeployer.sol";

interface ERC1155 {
    function mint(address _to, uint256 _token_id, uint256 _amount) external;
    function balanceOf(address _owner, uint256 _id) external view returns (uint256);
    function setApprovalForAll(address _operator, bool _approved) external;
    function isApprovedForAll(address _owner, address _operator) external view returns (bool);
    function safeTransferFrom(address _from, address _to, uint256 _id, uint256 _value, bytes calldata _data) external;
    function balanceOfBatch(address[] calldata _owners, uint256[] calldata _ids)
        external
        view
        returns (uint256[] memory);
    function safeBatchTransferFrom(
        address _from,
        address _to,
        uint256[] calldata _ids,
        uint256[] calldata _values,
        bytes calldata _data
    ) external;
}

contract ERC1155Test is Test {
    event TransferSingle(
        address indexed _operator, address indexed _from, address indexed _to, uint256 _id, uint256 _value
    );
    event TransferBatch(
        address indexed _operator, address indexed _from, address indexed _to, uint256[] _ids, uint256[] _values
    );
    event ApprovalForAll(address indexed _owner, address indexed _operator, bool _approved);
    event URI(string _value, uint256 indexed _id);

    YulDeployer yulDeployer = new YulDeployer();

    ERC1155 ERC1155Contract;
    address alice;
    address bob;
    address charlie;

    function setUp() public {
        ERC1155Contract = ERC1155(yulDeployer.deployContract("ERC1155"));
        alice = address(0x1);
        bob = address(0x2);
        charlie = address(0x3);
    }

    function testMintAndBalanceOf() public {
        vm.startPrank(address(yulDeployer));

        ERC1155Contract.mint(alice, 1, 123_456);
        assertEq(ERC1155Contract.balanceOf(alice, 1), 123_456);
        ERC1155Contract.mint(bob, 1, 1e18);
        assertEq(ERC1155Contract.balanceOf(bob, 1), 1e18);

        vm.stopPrank();

        assertEq(ERC1155Contract.balanceOf(bob, 0), 0);
        assertEq(ERC1155Contract.balanceOf(charlie, 99), 0);
    }

    function testApproveAll() public {
        vm.prank(alice);
        ERC1155Contract.setApprovalForAll(bob, true);

        bool approved = ERC1155Contract.isApprovedForAll(alice, bob);
        assert(approved);

        approved = ERC1155Contract.isApprovedForAll(alice, charlie);
        assertEq(approved, false);
    }

    function testApproveAndRevoke() public {
        vm.prank(alice);
        ERC1155Contract.setApprovalForAll(bob, true);
        bool approved = ERC1155Contract.isApprovedForAll(alice, bob);

        assert(approved);

        vm.prank(alice);
        ERC1155Contract.setApprovalForAll(bob, false);
        approved = ERC1155Contract.isApprovedForAll(alice, bob);

        assertEq(approved, false);
    }

    function testSafeTransferFrom() public {
        vm.prank(address(yulDeployer));
        ERC1155Contract.mint(alice, 1, 100);

        vm.prank(alice);
        ERC1155Contract.safeTransferFrom(alice, bob, 1, 10, hex"00");

        assertEq(ERC1155Contract.balanceOf(bob, 1), 10);
    }

    function testSafeTransferFromApproved() public {
        vm.prank(address(yulDeployer));
        ERC1155Contract.mint(alice, 1, 100);

        vm.prank(alice);
        ERC1155Contract.setApprovalForAll(bob, true);

        vm.prank(bob);
        ERC1155Contract.safeTransferFrom(alice, bob, 1, 99, hex"00");

        assertEq(ERC1155Contract.balanceOf(bob, 1), 99);
    }

    function testBalanceOfBatch() public {
        vm.startPrank(address(yulDeployer));
        ERC1155Contract.mint(alice, 7, 111_000);
        ERC1155Contract.mint(bob, 8, 222_000);
        ERC1155Contract.mint(charlie, 9, 333_000);
        ERC1155Contract.mint(alice, 777, 999_000);
        vm.stopPrank();

        address[] memory addrs = new address[](4);
        addrs[0] = alice;
        addrs[1] = bob;
        addrs[2] = charlie;
        addrs[3] = alice;

        uint256[] memory ids = new uint256[](4);
        ids[0] = 7;
        ids[1] = 8;
        ids[2] = 9;
        ids[3] = 777;

        ERC1155Contract.balanceOfBatch(addrs, ids);
        uint256[] memory balances = ERC1155Contract.balanceOfBatch(addrs, ids);

        assertEq(balances[0], 111_000);
        assertEq(balances[1], 222_000);
        assertEq(balances[2], 333_000);
        assertEq(balances[3], 999_000);
    }

    function testBatchTransferFrom() public {
        vm.startPrank(address(yulDeployer));
        ERC1155Contract.mint(alice, 11, 100);
        ERC1155Contract.mint(alice, 22, 200);
        ERC1155Contract.mint(alice, 33, 300);
        vm.stopPrank();

        uint256[] memory ids = new uint256[](3);
        ids[0] = 11;
        ids[1] = 22;
        ids[2] = 33;

        uint256[] memory values = new uint256[](3);
        values[0] = 10;
        values[1] = 20;
        values[2] = 30;

        vm.prank(alice);
        ERC1155Contract.safeBatchTransferFrom(alice, bob, ids, values, hex"00");

        assertEq(ERC1155Contract.balanceOf(alice, 11), 90);
        assertEq(ERC1155Contract.balanceOf(alice, 22), 180);
        assertEq(ERC1155Contract.balanceOf(alice, 33), 270);

        assertEq(ERC1155Contract.balanceOf(bob, 11), 10);
        assertEq(ERC1155Contract.balanceOf(bob, 22), 20);
        assertEq(ERC1155Contract.balanceOf(bob, 33), 30);
    }

    function testTransferSingleEvent() public {
        vm.prank(address(yulDeployer));
        ERC1155Contract.mint(alice, 1, 100);

        vm.expectEmit(true, true, true, true);
        emit TransferSingle(alice, alice, bob, 1, 10);

        vm.prank(alice);
        ERC1155Contract.safeTransferFrom(alice, bob, 1, 10, hex"00");
        assertEq(ERC1155Contract.balanceOf(bob, 1), 10);
    }
}
