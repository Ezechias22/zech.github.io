document.addEventListener("DOMContentLoaded", function() {
    const lightbox = document.createElement("div");
    lightbox.classList.add("lightbox");
    document.body.appendChild(lightbox);

    const lightboxContent = document.createElement("div");
    lightbox.appendChild(lightboxContent);

    const lightboxMedia = document.createElement("img");
    lightboxMedia.style.maxWidth = "80%";
    lightboxMedia.style.maxHeight = "80vh";
    lightboxContent.appendChild(lightboxMedia);

    const closeButton = document.createElement("span");
    closeButton.innerHTML = "&times;";
    closeButton.classList.add("close");
    lightboxContent.appendChild(closeButton);

    document.querySelectorAll(".slide img, .slide video").forEach(media => {
        media.addEventListener("click", function() {
            lightboxContent.innerHTML = ""; // Nettoie le contenu précédent
            lightboxContent.appendChild(closeButton);

            if (this.tagName === "IMG") {
                lightboxMedia.src = this.src;
                lightboxMedia.style.display = "block";
                lightboxContent.appendChild(lightboxMedia);
            } else {
                const video = document.createElement("video");
                video.src = this.src;
                video.controls = true;
                video.style.maxWidth = "80%";
                video.style.maxHeight = "80vh";
                lightboxContent.appendChild(video);
            }
            lightbox.classList.add("active");
        });
    });

    closeButton.addEventListener("click", function() {
        lightbox.classList.remove("active");
        lightboxContent.innerHTML = ""; // Nettoie pour éviter l'accumulation de vidéos
    });
});
