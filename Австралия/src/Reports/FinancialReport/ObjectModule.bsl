#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region EventHandlers

Procedure FillCheckProcessing(Cancel, CheckedAttributes)
	
	If ValueIsFilled(BeginOfPeriod) And ValueIsFilled(EndOfPeriod) Then
		If EndOfPeriod < BeginOfPeriod Then
			MessageText = NStr("en = 'Period end should be later than its start'; ru = 'Конец периода должен быть больше начала';pl = 'Koniec okresu powinien być późniejszy niż jego początek';es_ES = 'Fin del período tiene que ser más tarde que su inicio';es_CO = 'Fin del período tiene que ser más tarde que su inicio';tr = 'Dönem sonu, başlangıcından sonra olmalıdır';it = 'La fine del periodo deve essere successiva all''inizio';de = 'Das Periodenende soll nach dem Start liegen'");
			CommonClientServer.MessageToUser(MessageText, ,"EndOfPeriod", "Report", Cancel);
		EndIf;
	EndIf;
	
EndProcedure

#EndRegion

#EndIf