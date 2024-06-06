// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import {FunctionsClient} from "@chainlink/contracts/src/v0.8/functions/dev/v1_0_0/FunctionsClient.sol";
import {FunctionsRequest} from "@chainlink/contracts/src/v0.8/functions/dev/v1_0_0/libraries/FunctionsRequest.sol";

contract MyTokenWithAPI is ERC721, ERC721URIStorage, Ownable, FunctionsClient {
    using FunctionsRequest for FunctionsRequest.Request;

    uint256 private _nextTokenId;
    bytes32 public lastRequestId;
    bytes public lastResponse;
    bytes public lastError;
    mapping(bytes32 => string) public requestURI; // requestId -> URI

    // Hardcoded for Fuji
    address router = 0xA9d587a00A31A52Ed70D6026794a8FC5E2F5dCb0;
    bytes32 donID = 0x66756e2d6176616c616e6368652d66756a692d31000000000000000000000000;
    uint32 gasLimit = 300000;
    uint64 public subscriptionId;

    string public source =
        "const url = args[0];"
        "const apiResponse = await Functions.makeHttpRequest({"
        "url: url,"
        "responseType: 'text'"
        "});"
        "if (apiResponse.error) {"
        "throw Error('Request failed');"
        "}"
        "const { data } = apiResponse;"
        "return Functions.encodeString(data);";

    event Response(bytes32 indexed requestId, string uri, bytes response, bytes err);

    constructor(uint64 functionsSubscriptionId, address initialOwner)
        ERC721("AUTO TOKEN", "SANZ")
        Ownable(initialOwner)
        FunctionsClient(router)
    {
        subscriptionId = functionsSubscriptionId;
    }

    function requestNFT(string memory apiUrl) public onlyOwner returns (bytes32 requestId) {
        string[] memory args = new string[](1);
        args[0] = apiUrl;

        FunctionsRequest.Request memory req;
        req.initializeRequestForInlineJavaScript(source); // Initialize the request with JS code
        req.setArgs(args); // Set the arguments for the request

        lastRequestId = _sendRequest(
            req.encodeCBOR(),
            subscriptionId,
            gasLimit,
            donID
        );
        
        requestURI[lastRequestId] = apiUrl;

        return lastRequestId;
    }

    function fulfillRequest(
        bytes32 requestId,
        bytes memory response,
        bytes memory err
    ) internal override {
        require(bytes(requestURI[requestId]).length != 0, "request not found");

        lastError = err;
        lastResponse = response;

        string memory uri = string(response);

        uint256 tokenId = _nextTokenId++;
        address owner = owner();

        _safeMint(owner, tokenId);
        _setTokenURI(tokenId, uri);

        emit Response(requestId, uri, lastResponse, lastError);
    }

    // The following functions are overrides required by Solidity.

    function tokenURI(uint256 tokenId)
        public
        view
        override(ERC721, ERC721URIStorage)
        returns (string memory)
    {
        return super.tokenURI(tokenId);
    }

    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(ERC721, ERC721URIStorage)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }
}
