#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region EventsHandlers

// Event handler procedure ChoiceDataGetProcessor.
//
Procedure ChoiceDataGetProcessing(ChoiceData, Parameters, StandardProcessing)
	
	If Parameters.Filter.Property("Owner")
		AND ValueIsFilled(Parameters.Filter.Owner)
		AND Not Parameters.Filter.Owner.UseBatches Then
		
		If Not UsersClientServer.IsExternalUserSession() Then
			MessageText = NStr("en = 'Accounting by batches is not kept for products.'; ru = 'Для номенклатуры не ведется учет по партиям!';pl = 'Ewidencja według partii nie jest stosowana dla produktów.';es_ES = 'Contabilidad por lotes no se ha guardado para los productos.';es_CO = 'Contabilidad por lotes no se ha guardado para los productos.';tr = 'Ürünler için muhasebeleştirme parti bazında yapılmaz.';it = 'Contabilità per lotti non è gestita per gli articoli.';de = 'Die Abrechnung nach Chargen wird für Produkte nicht gepflegt.'");
			CommonClientServer.MessageToUser(MessageText);
		EndIf;
		StandardProcessing = False;
		
	EndIf;
	
	NativeLanguagesSupportServer.ChoiceDataGetProcessing(
		ChoiceData,
		Parameters,
		StandardProcessing,
		Metadata.Catalogs.ProductsBatches);
	
EndProcedure

Procedure PresentationGetProcessing(Data, Presentation, StandardProcessing)
	
	NationalLanguageSupportClientServer.PresentationGetProcessing(Data, Presentation, StandardProcessing);
	
EndProcedure

Procedure PresentationFieldsGetProcessing(Fields, StandardProcessing)
	
	NationalLanguageSupportClientServer.PresentationFieldsGetProcessing(Fields, StandardProcessing);
	
EndProcedure

#EndRegion

#Region Public

#Region ObjectAttributesLock

// StandardSubsystems.ObjectAttributesLock

// See ObjectsAttributesEditBlockedOverridable.OnDefineObjectsWithLockedAttributes. 
Function GetObjectAttributesToLock() Export
	
	AttributesToLock = New Array;
	
	AttributesToLock.Add("Owner");
	
	Return AttributesToLock;
EndFunction

// End StandardSubsystems.ObjectAttributesLock

// Function returns the list of the "key" attribute names.
//
Function GetObjectAttributesBeingLocked() Export
	
	Result = New Array;
	Result.Add("Owner");
	
	Return Result;
	
EndFunction

#EndRegion

#EndRegion

#EndIf
