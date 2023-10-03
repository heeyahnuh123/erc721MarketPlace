// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";

contract ERC721Marketplace is IERC721Receiver {
    using Address for address;
    using ECDSA for bytes32;

    struct Order {
        address seller;
        address buyer;
        uint256 tokenId;
        uint256 price;
        bool isConfirmed;
    }

    mapping(bytes32 => Order) public orders;

    IERC721 public nftContract;

    constructor(address _nftContract) {
        nftContract = IERC721(_nftContract);
    }

    function createOrder(
        uint256 _tokenId,
        uint256 _price,
        bytes calldata _signature
    ) external {
        bytes32 orderId = keccak256(
            abi.encodePacked(msg.sender, _tokenId, _price)
        );
        require(orders[orderId].seller == address(0), "Order already exists");

        require(_verifySignature(orderId, _signature), "Invalid signature");

        orders[orderId] = Order({
            seller: msg.sender,
            buyer: address(0),
            tokenId: _tokenId,
            price: _price,
            isConfirmed: false
        });
    }

    function confirmOrder(bytes32 _orderId) external payable {
        Order storage order = orders[_orderId];
        require(order.seller != address(0), "Order does not exist");
        require(!order.isConfirmed, "Order already confirmed");
        require(msg.value == order.price, "Incorrect payment amount");

        order.buyer = msg.sender;
        order.isConfirmed = true;

        nftContract.safeTransferFrom(order.seller, order.buyer, order.tokenId);
    }

    function _verifySignature(
        bytes32 _messageHash,
        bytes memory _signature
    ) internal view returns (bool) {
        address signer = _messageHash.toEthSignedMessageHash().recover(
            _signature
        );
        return signer == orders[_messageHash].seller;
    }

    function onERC721Received(
        address,
        address,
        uint256,
        bytes calldata
    ) external pure override returns (bytes4) {
        return this.onERC721Received.selector;
    }
}
