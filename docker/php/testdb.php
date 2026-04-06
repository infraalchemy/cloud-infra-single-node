<?php
$mysqli = new mysqli("mysql", "moodleuser", "yourpassword", "moodle");

if ($mysqli->connect_error) {
    die("Connection failed: " . $mysqli->connect_error);
}
echo "Connected successfully to MySQL!";
