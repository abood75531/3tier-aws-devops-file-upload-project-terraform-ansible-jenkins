const BACKEND_API_URL = "http://BACKEND_PUBLIC_IP/upload.php";

function uploadFile() {
    const fileInput = document.getElementById("fileInput");
    const status = document.getElementById("status");

    if (fileInput.files.length === 0) {
        status.innerHTML = "Please select a file.";
        status.style.color = "red";
        return;
    }

    const file = fileInput.files[0];
    const formData = new FormData();
    formData.append("file", file);

    status.innerHTML = "Uploading...";
    status.style.color = "black";

    fetch(BACKEND_API_URL, {
        method: "POST",
        body: formData
    })
    .then(response => response.json())
    .then(data => {
        if (data.success) {
            status.innerHTML = `
                File uploaded successfully.<br>
                <a href="${data.url}" target="_blank">View File</a>
            `;
            status.style.color = "green";
        } else {
            status.innerHTML = data.message;
            status.style.color = "red";
        }
    })
    .catch(error => {
        console.error(error);
        status.innerHTML = "Upload failed. Try again.";
        status.style.color = "red";
    });
}
