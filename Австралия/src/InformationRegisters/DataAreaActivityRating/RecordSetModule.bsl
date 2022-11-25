#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region EventHandlers

Procedure OnWrite(Cancel, Replacing)
	
	// There is no DataExchange.Load property value verification, because the limitations imposed by the 
	// script should not be bypassed by passing True to the Load property (on the side of the script 
	// that records to this register).
	//
	// This register cannot be included in any exchanges or data import or export operations if the data 
	// area separation is enabled.
	
	If Not SaaS.SessionWithoutSeparators() Then
		
		Raise NStr("ru = 'Нарушение прав доступа.'; en = 'Access right violation.'; pl = 'Naruszenie praw dostępu.';es_ES = 'Violación del derecho de acceso.';es_CO = 'Violación del derecho de acceso.';tr = 'Erişim hakkı ihlali.';it = 'Violazione permessi di accesso.';de = 'Verletzung von Zugriffsrechten.'");
		
	EndIf;
	
EndProcedure

#EndRegion

#EndIf