///////////////////////////////////////////////////////////////////////////////////////////////////////
// Copyright (c) 2019, 1C-Soft LLC
// All Rights reserved. This application and supporting materials are provided under the terms of 
// Attribution 4.0 International license (CC BY 4.0)
// The license text is available at:
// https://creativecommons.org/licenses/by/4.0/legalcode
///////////////////////////////////////////////////////////////////////////////////////////////////////

#Region Private

// For internal use.
Function GenerateMailingRecipientsList(Val RecipientsParameters) Export
	LogParameters = New Structure("EventName, Metadata, Data, ErrorArray, HadErrors");
	LogParameters.EventName   = NStr("ru = 'Рассылка отчетов. Формирование списка получателей'; en = 'Report bulk email. Generate recipient list'; pl = 'Masowa wysyłka raportów przez e-mail. Wygeneruj listę odbiorców';es_ES = 'Informe del newsletter. Generar la lista de destinatarios';es_CO = 'Informe del newsletter. Generar la lista de destinatarios';tr = 'Rapor toplu e-postası. Alıcı listesi düzenle';it = 'Invio massivo di report. Generare elenco destinatari';de = 'Bulk-Mail-Bericht. Empfängerliste generieren'", CommonClientServer.DefaultLanguageCode());
	LogParameters.ErrorArray = New Array;
	LogParameters.HadErrors   = False;
	LogParameters.Data       = RecipientsParameters.Ref;
	LogParameters.Metadata   = Metadata.Catalogs.ReportMailings;
	
	ExecutionResult = New Structure("Recipients, HadCriticalErrors, Text, More");
	ExecutionResult.Recipients = ReportMailing.GenerateMailingRecipientsList(RecipientsParameters, LogParameters);
	ExecutionResult.HadCriticalErrors = ExecutionResult.Recipients.Count() = 0;
	
	If ExecutionResult.HadCriticalErrors Then
		ExecutionResult.Text = ReportMailing.MessagesToUserString(LogParameters.ErrorArray, False);
	EndIf;
	
	Return ExecutionResult;
EndFunction

// Runs background job.
Function RunBackgroundJob(Val MethodParameters, Val UUID) Export
	MethodName = "ReportMailing.SendBulkEmailsInBackgroundJob";
	
	StartSettings = TimeConsumingOperations.BackgroundExecutionParameters(UUID);
	StartSettings.BackgroundJobDescription = NStr("ru = 'Рассылки отчетов: Выполнение рассылок в фоне'; en = 'Report bulk emails: Running in the background'; pl = 'Masowa wysyłka raportów przez e-mail. Działa w tle';es_ES = 'Informe del newsletter: Ejecutándose en segundo plano';es_CO = 'Informe del newsletter: Ejecutándose en segundo plano';tr = 'Rapor toplu e-postaları: Arka planda çalışıyor';it = 'Invio massivo dei report: Avvio in background';de = 'Bulk-Mail-Bericht: im Hintergrund ausführend'");
	
	Return TimeConsumingOperations.ExecuteInBackground(MethodName, MethodParameters, StartSettings);
EndFunction

#EndRegion
