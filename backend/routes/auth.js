const express = require('express');
const router = express.Router();
const jwt = require('jsonwebtoken');
const User = require('../models/User');
const { ethers } = require('ethers');

// Signup route
router.post('/signup', async (req, res) => {
  try {
    const { email, password, walletAddress } = req.body;

    // Validate wallet address
    if (!ethers.isAddress(walletAddress)) {
      return res.status(400).json({ error: 'Invalid wallet address' });
    }

    // Check if user already exists
    const existingUser = await User.findOne({
      $or: [{ email }, { walletAddress }]
    });

    if (existingUser) {
      return res.status(400).json({
        error: 'User with this email or wallet address already exists'
      });
    }

    // Create new user
    const user = new User({
      email,
      password,
      walletAddress
    });

    await user.save();

    // Generate JWT token
    const token = jwt.sign(
      { userId: user._id, walletAddress: user.walletAddress },
      process.env.JWT_SECRET,
      { expiresIn: '24h' }
    );

    res.status(201).json({
      message: 'User created successfully',
      token,
      walletAddress: user.walletAddress
    });
  } catch (error) {
    res.status(500).json({ error: 'Error creating user' });
  }
});

// Signin route
router.post('/signin', async (req, res) => {
  try {
    const { email, password } = req.body;

    // Find user
    const user = await User.findOne({ email });
    if (!user) {
      return res.status(401).json({ error: 'Invalid credentials' });
    }

    // Check password
    const isMatch = await user.comparePassword(password);
    if (!isMatch) {
      return res.status(401).json({ error: 'Invalid credentials' });
    }

    // Generate JWT token
    const token = jwt.sign(
      { userId: user._id, walletAddress: user.walletAddress },
      process.env.JWT_SECRET,
      { expiresIn: '24h' }
    );

    res.json({
      message: 'Login successful',
      token,
      walletAddress: user.walletAddress
    });
  } catch (error) {
    res.status(500).json({ error: 'Error signing in' });
  }
});

module.exports = router;
