<?php
if ($_SERVER["REQUEST_METHOD"] == "POST") {
    // Récupérer les données du formulaire
    $name = htmlspecialchars($_POST['name']);
    $email = htmlspecialchars($_POST['email']);
    $message = htmlspecialchars($_POST['message']);

    // Définir l'adresse email à partir de laquelle l'email sera envoyé
    $to = "contact@zechia.com"; // L'adresse email du destinataire
    $subject = "Message de contact de $name";
    
    // Corps de l'email
    $body = "Nom: $name\n";
    $body .= "Email: $email\n\n";
    $body .= "Message:\n$message\n";

    // En-têtes de l'email
    $headers = "From: $email\r\n";
    $headers .= "Reply-To: $email\r\n";
    $headers .= "Content-Type: text/plain; charset=UTF-8\r\n";

    // Envoi de l'email
    if (mail($to, $subject, $body, $headers)) {
        echo "Message envoyé avec succès ! Nous vous répondrons dans les plus brefs délais.";
    } else {
        echo "Une erreur est survenue. Veuillez réessayer plus tard.";
    }
}
?>
