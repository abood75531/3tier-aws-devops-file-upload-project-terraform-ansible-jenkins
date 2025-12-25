<?php
header('Content-Type: application/json');

/* ===============================
   BASIC VALIDATION
================================ */
if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
    echo json_encode([
        "success" => false,
        "message" => "Invalid request method"
    ]);
    exit;
}

if (!isset($_FILES['file'])) {
    echo json_encode([
        "success" => false,
        "message" => "No file received"
    ]);
    exit;
}

/* ===============================
   FILE INFO
================================ */
$fileName = time() . "_" . basename($_FILES['file']['name']);
$tmpPath  = $_FILES['file']['tmp_name'];

/* ===============================
   AWS SDK
================================ */
require __DIR__ . '/vendor/autoload.php';

use Aws\S3\S3Client;
use Aws\Sns\SnsClient;

/* ===============================
   AWS CONFIG
================================ */
$bucketName   = "file-upload-dbdb4fe2";
$cloudfront   = "https://dx9okb1mt21ue.cloudfront.net";
$snsTopicArn  = "arn:aws:sns:ap-south-1:266731137793:file-upload-topic";
$region       = "ap-south-1";

/* ===============================
   DATABASE CONFIG
================================ */
$dbHost = "10.0.3.215";
$dbUser = "fileuser";
$dbPass = "File@1234";
$dbName = "file_upload_db";

/* ===============================
   DB CONNECTION
================================ */
$conn = new mysqli($dbHost, $dbUser, $dbPass, $dbName);
if ($conn->connect_error) {
    echo json_encode([
        "success" => false,
        "message" => "Database connection failed"
    ]);
    exit;
}

/* ===============================
   AWS CLIENTS
================================ */
$s3 = new S3Client([
    'version' => 'latest',
    'region'  => $region
]);

$sns = new SnsClient([
    'version' => 'latest',
    'region'  => $region
]);

/* ===============================
   MAIN LOGIC
================================ */
try {

    /* ---- Upload to S3 ---- */
    $s3->putObject([
        'Bucket'     => $bucketName,
        'Key'        => $fileName,
        'SourceFile'=> $tmpPath,
        'ACL'        => 'public-read'
    ]);

    $fileUrl = $cloudfront . "/" . $fileName;

    /* ---- Insert into DB ---- */
    $stmt = $conn->prepare(
        "INSERT INTO uploads (file_name, s3_url) VALUES (?, ?)"
    );
    $stmt->bind_param("ss", $fileName, $fileUrl);
    $stmt->execute();

    /* ---- SNS Notification ---- */
    $sns->publish([
        'TopicArn' => $snsTopicArn,
        'Message'  => "New file uploaded: " . $fileUrl
    ]);

    /* ---- SUCCESS RESPONSE ---- */
    echo json_encode([
        "success" => true,
        "url"     => $fileUrl
    ]);

} catch (Exception $e) {

    echo json_encode([
        "success" => false,
        "message" => "Upload failed: " . $e->getMessage()
    ]);
}
