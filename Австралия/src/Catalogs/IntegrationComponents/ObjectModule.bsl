#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region EventHandlers

Procedure BeforeWrite(Cancel)
	
	If DataExchange.Load Then
	     Return;
	EndIf;
	
	If Not IsFilled Then
		Message = NStr("en = 'Please attach an external data processor for data exchange with a website.'; ru = 'Подключите внешнюю обработку для обмена данными с веб-сайтом.';pl = 'Podłącz zewnętrzny procesor danych do wymiany danych ze stroną internetową.';es_ES = 'Por favor, adjunte un procesador de datos externo para el intercambio de datos con un sitio web.';es_CO = 'Por favor, adjunte un procesador de datos externo para el intercambio de datos con un sitio web.';tr = 'Web sitesi ile veri değişimi için lütfen harici veri işlemcisi ekleyin.';it = 'Allegare un elaboratore dati esterno per lo scambio dati con un sito web.';de = 'Bitte fügen Sie einen externen Datenprozessor für den Datenaustausch mit einer Webseite bei.'");
		CommonClientServer.MessageToUser(Message,
			,
			,
			,
			Cancel);
	EndIf;
	
EndProcedure

#EndRegion

#EndIf