//SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;


abstract contract IShop {
    event ItemAdded(bytes32 sku);
    event ItemEdited(bytes32 sku);
    event ItemDisabled(bytes32 sku);
    event ItemEnabled(bytes32 sku);
    event ItemRestocked(bytes32 sku, uint256 amount);
    event ItemBought(bytes32 sku, uint256 amount, address buyer);

    /**
     * @dev Adds a new item
     * Must check if item already exists with revert message "Item exists"
     *
     * Emits: ItemAdded, ItemRestocked
     */
    function addItem(
        string calldata name,
        string calldata imageUrl,
        string calldata description,
        uint256 amount,
        uint256 price,
        uint256 points
    ) external virtual;

    /**
     * @dev Edits an existing item
     * Must check if item already exists with revert message "Item doesn't exist"
     *
     * This isn't the most efficient way of doing things, I am aware
     *
     * Emits: ItemEdited
     */
    function editItem(
        bytes32 sku,
        string calldata imageUrl,
        string calldata description,
        uint256 price,
        uint256 points
    ) external virtual;

    /**
     * @dev Disables an item so it cannot be purchased
     *
     * Emits: ItemDisabled
     */
    function disableItem(bytes32 sku) external virtual;

    /**
     * @dev Enables an item so it can be purchased
     *
     * Emits: ItemEnabled
     */
    function enableItem(bytes32 sku) external virtual;

    /**
     * @dev Restocks an item
     *
     * Emits: ItemRestocked
     */
    function restockItem(bytes32 sku, uint256 amount) external virtual;

    /**
     * @dev Administrator can withdraw shop proceeds
     */
    function withdraw() external virtual;

    /**
     * @dev Shopper can buy an item with Ether or points
     * Must check if item already exists & isn't disabled
     * Shopper cannot mix Ether and points (all Ether or all points)
     *
     * Emits: ItemBought
     */
    function buy(
        bytes32 sku,
        uint256 amount,
        bool usePoints
    ) external payable virtual;

    /**
     * @dev Returns information regarding an item
     */
    function getItem(
        bytes32 sku
    )
        external
        view
        virtual
        returns (
            string memory name,
            string memory imageUrl,
            string memory description,
            uint256 amount,
            uint256 price,
            uint256 points,
            bool disabled
        );

    /**
     * @dev Returns membership point information for a user
     */
    function getPoints(address user) external view virtual returns (uint256);

    function generateSku(string memory name) public pure returns (bytes32) {
        return keccak256(abi.encode(name));
    }
}

contract Shop is IShop {
    struct Item {
        string name;
        string imageUrl;
        string description;
        uint256 amount;
        uint256 price;
        uint256 points;
        bool itemDisabled;
        bool itemExists;
    }
    address private admin;
    mapping(bytes32 => Item) private _items;
    uint256 private shopBalance;
    mapping(address => uint256) private userPoints;

    modifier onlyAdmin() {
        require(msg.sender == admin, "Not Admin");
        _;
    }

    constructor() {
        admin = msg.sender;
    }

    function addItem(
        string calldata name,
        string calldata imageUrl,
        string calldata description,
        uint256 amount,
        uint256 price,
        uint256 points
    ) external virtual override {
        bytes32 sku = generateSku(name);
        Item storage i = _items[sku];
        require(i.itemExists == false, "Item exists");
        i.name = name;
        i.imageUrl = imageUrl;
        i.description = description;
        i.amount = amount;
        i.price = price;
        i.points = points;
        i.itemExists = true;
        i.itemDisabled = false;
        emit ItemAdded(sku);
    }

    function editItem(
        bytes32 sku,
        string calldata imageUrl,
        string calldata description,
        uint256 price,
        uint256 points
    ) external virtual override {
        Item storage i = _items[sku];
        require(i.itemExists == true, "Item doesn't exist");
        i.imageUrl = imageUrl;
        i.description = description;
        i.price = price;
        i.points = points;
        emit ItemEdited(sku);
    }

    function disableItem(bytes32 sku) external virtual override {
        Item storage i = _items[sku];
        require(i.itemDisabled == false, "Already disabled");
        i.itemDisabled = true;
        emit ItemDisabled(sku);
    }

    function enableItem(bytes32 sku) external virtual override {
        Item storage i = _items[sku];
        require(i.itemDisabled == true, "Already enabled");
        i.itemDisabled = false;
        emit ItemEnabled(sku);
    }

    function restockItem(
        bytes32 sku,
        uint256 amount
    ) external virtual override {
        Item storage i = _items[sku];
        require(i.itemExists == true, "Item doesn't exist");
        i.amount += amount;
        emit ItemRestocked(sku, amount);
    }

    function withdraw() external virtual override onlyAdmin {
        payable(msg.sender).transfer(shopBalance);
        shopBalance = 0;
    }

    function buy(
        bytes32 sku,
        uint256 amount,
        bool usePoints
    ) external payable virtual override {
        Item storage i = _items[sku];
        require(i.itemExists == true, "Item doesn't exist");
        require(i.itemDisabled == false, "Item disabled");
        require(i.amount >= amount, "Not enough stock");
        if (usePoints == true) {
            require(msg.value == 0, "Don't send Ether");
            require(
                userPoints[msg.sender] >= (i.points * amount),
                "Not enough points"
            );
            i.amount -= amount;
            userPoints[msg.sender] -= (i.points * amount);
            emit ItemBought(sku, amount, msg.sender);
        } else {
            require(msg.value == i.price * amount, "Bad Ether value");
            i.amount -= amount;
            shopBalance += msg.value;
            userPoints[msg.sender] += (amount * i.points);
            emit ItemBought(sku, amount, msg.sender);
        }
    }

    function getItem(
        bytes32 sku
    )
        external
        view
        virtual
        override
        returns (
            string memory name,
            string memory imageUrl,
            string memory description,
            uint256 amount,
            uint256 price,
            uint256 points,
            bool disabled
        )
    {
        Item storage i = _items[sku];
        require(i.itemExists == true, "Item doesn't exist");
        return (
            i.name,
            i.imageUrl,
            i.description,
            i.amount,
            i.price,
            i.points,
            i.itemDisabled
        );
    }

    function getPoints(
        address user
    ) external view virtual override returns (uint256) {
        return userPoints[user];
    }
}
