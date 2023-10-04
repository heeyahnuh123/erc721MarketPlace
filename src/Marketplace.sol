// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";

contract ERC721Marketplace is IERC721Receiver {
    using Address for address;
    using ECDSA for bytes32;

    struct Listing {
        address payable seller;
        address payable buyer;
        uint256 tokenId;
        uint256 price;
        uint256 deadline;
        bool isConfirmed;
    }

    mapping(uint256 => Listing) public listings; // Use an incrementing ID for listings
    uint256 public listingCount = 0; // Keep track of the number of listings

    IERC721 public nftContract;

    event ListingCreated(
        uint256 listingId,
        address seller,
        uint256 tokenId,
        uint256 price,
        uint256 deadline
    );
    event ListingConfirmed(uint256 listingId, address buyer);

    constructor(address _nftContract) {
        nftContract = IERC721(_nftContract);
    }

    function createListing(
        uint256 _tokenId,
        uint256 _price,
        uint256 _deadline,
        bytes calldata _signature
    ) external payable {
        uint256 listingId = listingCount; // Use listingCount as the ID
        listingCount++; // Increment the listingCount

        bytes32 listingHash = keccak256(
            abi.encodePacked(listingId, msg.sender, _tokenId, _price, _deadline)
        );
        require(
            listings[listingId].seller == address(0),
            "Listing already exists"
        );

        require(listingId < listingCount, "Invalid listing ID");
        require(msg.value == _price, "Incorrect payment amount");
        require(block.timestamp <= _deadline, "Listing deadline has passed");
        require(_verifyVRS(listingHash, _signature), "Invalid VRS signature");

        listings[listingId] = Listing({
            seller: payable(msg.sender),
            buyer: payable(address(0)),
            tokenId: _tokenId,
            price: _price,
            deadline: _deadline,
            isConfirmed: false
        });

        emit ListingCreated(listingId, msg.sender, _tokenId, _price, _deadline);
    }

    function confirmListing(uint256 _listingId) external payable {
        Listing storage listing = listings[_listingId];
        require(listing.seller != address(0), "Listing does not exist");
        require(!listing.isConfirmed, "Listing already confirmed");
        require(msg.value == listing.price, "Incorrect payment amount");
        require(
            block.timestamp <= listing.deadline,
            "Listing deadline has passed"
        );

        listing.buyer = payable(msg.sender);
        listing.isConfirmed = true;

        nftContract.safeTransferFrom(
            listing.seller,
            listing.buyer,
            listing.tokenId
        );

        // Transfer Ether from buyer to seller
        (bool success, ) = listing.seller.call{value: msg.value}("");
        require(success, "Transfer failed");

        emit ListingConfirmed(_listingId, msg.sender);
    }

    function _verifyVRS(
        bytes32 _messageHash,
        bytes memory _signature
    ) internal view returns (bool) {
        address signer = ECDSA.recover(_messageHash, _signature);
        return signer == listings[uint256(_messageHash)].seller;
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
