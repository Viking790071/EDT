#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region EventsHandlers

Procedure OnCopy(CopiedObject)
	
	Code = "";
	
EndProcedure

Procedure FillCheckProcessing(Cancel, CheckedAttributes)
	
	If DataExchange.Load Then
		Return;
	EndIf;
			
	If Not IsFolder Then
	
		If StrLen(TrimAll(Code)) <> 8 AND StrLen(TrimAll(Code)) <> 11 Then
			MessageText = NStr("en = 'SWIFT must have 8 or 11 characters.'; ru = 'SWIFT банка должен иметь 8 или 11 знаков.';pl = 'SWIFT musi mieć 8 lub 11 znaków.';es_ES = 'El SWIFT tiene que tener entre 8 y 11 símbolos.';es_CO = 'El SWIFT tiene que tener entre 8 y 11 símbolos.';tr = 'SWIFT 8 veya 11 karakter içermelidir.';it = 'Lo SWIFT deve avere 8 o 11 caratteri.';de = 'SWIFT muss 8 oder 11 Zeichen haben.'");
			DriveServer.ShowMessageAboutError(
				ThisObject,
				MessageText,
				,
				,
				"Code",
				Cancel
			);
		EndIf;

	Else
		
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "Code");
		
	EndIf;
	
EndProcedure

#EndRegion

#EndIf