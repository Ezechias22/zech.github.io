// android/app/src/main/kotlin/com/lovingo/app/CallActionReceiver.kt
package com.lovingo.app

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.app.NotificationManager
import android.util.Log

class CallActionReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context?, intent: Intent?) {
        Log.d("CallActionReceiver", "Action reçue: ${intent?.action}")
        
        when (intent?.action) {
            "ACCEPT_CALL" -> {
                val callId = intent.getStringExtra("callId")
                Log.d("CallActionReceiver", "Accepter appel: $callId")
                
                // Annuler la notification
                val notificationManager = context?.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
                notificationManager.cancel(callId.hashCode())
                
                // Ouvrir l'app avec l'appel
                val launchIntent = Intent(context, MainActivity::class.java).apply {
                    flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TASK
                    putExtra("action", "accept_call")
                    putExtra("callId", callId)
                }
                context?.startActivity(launchIntent)
            }
            
            "DECLINE_CALL" -> {
                val callId = intent.getStringExtra("callId")
                Log.d("CallActionReceiver", "Refuser appel: $callId")
                
                // Annuler la notification
                val notificationManager = context?.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
                notificationManager.cancel(callId.hashCode())
                
                // Optionnel: Envoyer signal de refus via Firebase
                // TODO: Implémenter refus via API
            }
        }
    }
}