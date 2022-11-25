

#Region EventSubscriptionHandler

Procedure FormGetProcessing(FormType, Parameters, SelectedForm, AdditionalInfo, StandardProcessing)
	
	#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then
		
		If Parameters <> Undefined AND Parameters.Property("OpenByScenario") Then
			StandardProcessing = False;
			InformationKind = Parameters.ContactInformationKind;
			SelectedForm = ContactInformationInputFormName(InformationKind);
			
			If SelectedForm = Undefined Then
				Raise NStr("en = 'Not processed type addresses:'; ru = 'Необработанные адреса:';pl = 'Nie przetworzono adresów o typie:';es_ES = 'Tipo de direcciones no procesado:';es_CO = 'Tipo de direcciones no procesado:';tr = 'İşlenmemiş tür adresleri:';it = 'Tipi di indirizzi non processati:';de = 'Nicht verarbeitete Adresstypen:'") + " " + InformationKind;
			EndIf;
		EndIf;
		
	#EndIf
	
EndProcedure

#EndRegion

#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region Private

// Returns a name of the form used to edit contact information type.
//
// Parameters:
//      ContactsKind - EnumRef.ContactsTypes, CatalogRef.ContactsKinds - requested type.
//                      
//
// Returns:
//      String - a full name of the form.
//
Function ContactInformationInputFormName(Val InformationKind)
	
	InformationType = ContactInformationManagementInternalCached.ContactInformationKindType(InformationKind);
	
	AllTypes = "Enum.ContactInformationTypes.";
	If InformationType = PredefinedValue(AllTypes + "Address") Then
		
		If Metadata.DataProcessors.Find("AdvancedContactInformationInput") = Undefined Then
			Return "DataProcessor.ContactInformationInput.Form.FreeFormAddressInput";
		Else
			Return "DataProcessor.AdvancedContactInformationInput.Form.AddressInput";
		EndIf;
		
	ElsIf InformationType = PredefinedValue(AllTypes + "Phone") Then
		Return "DataProcessor.ContactInformationInput.Form.PhoneInput";
		
	ElsIf InformationType = PredefinedValue(AllTypes + "Fax") Then
		Return "DataProcessor.ContactInformationInput.Form.PhoneInput";
		
	EndIf;
	
	Return Undefined;
	
EndFunction

#EndRegion

#EndIf


