#Region Public

// The function returns description of metadata types for which it is required to extract email addresses
//
Function GetTypesOfMetadataContainingAffiliateEmail() Export
	
	ListOfMetadataTypesContainingEmails = New ValueList;
	
	ListOfMetadataTypesContainingEmails.Add(New TypeDescription("CatalogRef.Counterparties"));
	ListOfMetadataTypesContainingEmails.Add(New TypeDescription("CatalogRef.ContactPersons"));
	
	Return ListOfMetadataTypesContainingEmails;
	
EndFunction

// The function generates recipients with email addresses to send an email.
//
// Parameters:
//  Recipients			 - Values list	 - valid types of items CatalogRef.Counterparties, CatalogRef.ContactPersons
//  WithSubordinate - Boolean	 - shows that contact persons for counterparties are included in the result 
// Return value:
//  Array - Array of structures , string keys:
//   * Presentation - CatalogRef.Counterparties, CatalogRef.ContactPersons
//   * Address - String
//   * Name - not used
Function PrepareRecipientsEmailAddresses(val Recipients, Recursive = True) Export
	
	RecipientsEmailAddresses = New Array;
	If Recipients.Count() = 0 Then
		Return RecipientsEmailAddresses;
	EndIf;
	EmailAddress = Enums.ContactInformationTypes.EmailAddress;
	
	ArrayOfRecipients = Recipients.UnloadValues();
	TableEmail = ContactsManager.ObjectsContactInformation(ArrayOfRecipients, EmailAddress);
	
	For Each Recipient In Recipients Do
		
		ValueListElementValue = Recipient.Value;
		
		AddressesEP = "";
		FoundStringArray = TableEmail.FindRows(New Structure("Object", ValueListElementValue));
		For Each CIRow In FoundStringArray Do
			AddressesEP = AddressesEP + ?(AddressesEP = "", "", ", ") + CIRow.Presentation;
		EndDo;
		
		StructureRecipient = New Structure("Presentation, Address, EmailAddressKind, ContactInformationSource");
		StructureRecipient.Presentation = ValueListElementValue;
		StructureRecipient.Address = AddressesEP;
		
		RecipientsEmailAddresses.Add(StructureRecipient);
		
		// Receive Email contact persons with help of recursion
		If Recursive 
			AND TypeOf(ValueListElementValue) = Type("CatalogRef.Counterparties") Then
			
			ContactPersonsEmailAddresses = PrepareRecipientsEmailAddresses(
				DriveServer.GetCounterpartyContactPersons(ValueListElementValue),
				False);
			
			For Each ItemOfAddress In ContactPersonsEmailAddresses Do
				
				RecipientsEmailAddresses.Add(ItemOfAddress);
				
			EndDo;
			
		EndIf;
		
	EndDo;
	
	Return RecipientsEmailAddresses;
	
EndFunction

// The function returns field value "FieldsValues" of contact information
//
// Ref - ref to catalog (Organization, Counterparty)
//  ContactInformationKind - contact information kind (Catalog.ContactInformationKinds)
//
Function GetValueOfContactInformationFields(Ref, ContactInformationKind) Export
	
	If Not ValueIsFilled(Ref) 
		OR Not ValueIsFilled(ContactInformationKind) Then
		
		Return "";
		
	EndIf;
	
	ContactInformation = Ref.ContactInformation.Find(ContactInformationKind, "Kind");
	If ContactInformation = Undefined Then
		
		Return "";
		
	EndIf;
	
	Return ContactInformation.FieldValues;
	
EndFunction

// Determines that the email recipient is multiway
//
Function MoreThenOneRecipient(Recipient) Export
	
	If TypeOf(Recipient) = Type("Array") Or TypeOf(Recipient) = Type("ValueList") Then
		
		Return Recipient.Count() > 1;
		
	Else
		
		Return CommonClientServer.EmailsFromString(Recipient).Count() > 1;
		
	EndIf;
	
EndFunction

Function GetContactsRefs(ObjectRef) Export
	
	RecipientsOwners = New Array;
	
	If Common.RefTypeValue(ObjectRef) And ValueIsFilled(ObjectRef) Then
		
		If TypeOf(ObjectRef) = Type("CatalogRef.Counterparties") Or TypeOf(ObjectRef) = Type("CatalogRef.ContactPersons") Then
			
			RecipientsOwners.Add(ObjectRef);
			
			If TypeOf(ObjectRef) = Type("CatalogRef.Counterparties") Then
				
				AddCounterpartyContactPersons(RecipientsOwners, ObjectRef)
				
			EndIf;
			
		Else
			
			RecipientsOwnersTypes = New Array;
			RecipientsOwnersTypes.Add(New TypeDescription("CatalogRef.Counterparties"));
			RecipientsOwnersTypes.Add(New TypeDescription("CatalogRef.ContactPersons"));
			
			ObjectMetadata = ObjectRef.Metadata();
			AttributesNames = New Structure;
			
			For Each MetadataItem In ObjectMetadata.Attributes Do
				
				If RecipientsOwnersTypes.Find(MetadataItem.Type) <> Undefined Then
					AttributesNames.Insert(MetadataItem.Name);
				EndIf;
				
			EndDo;
			
			If AttributesNames.Count() > 0 Then
				
				AttributesValuesStructure = Common.ObjectAttributesValues(ObjectRef, AttributesNames);
				
				For Each StructureItem In AttributesValuesStructure Do
					
					If ValueIsFilled(StructureItem.Value) And RecipientsOwners.Find(StructureItem.Value) = Undefined Then
						
						RecipientsOwners.Add(StructureItem.Value);
						
						If TypeOf(StructureItem.Value) = Type("CatalogRef.Counterparties") Then
							
							AddCounterpartyContactPersons(RecipientsOwners, StructureItem.Value)
							
						EndIf;
						
					EndIf;
					
				EndDo;
				
			EndIf;
			
		EndIf;
		
	EndIf;
	
	Return RecipientsOwners;
	
EndFunction

#EndRegion

#Region Private

Procedure AddCounterpartyContactPersons(RecipientsOwners, Counterparty)
	
	Query = New Query;
	Query.Text = 
	"SELECT ALLOWED
	|	ContactPersons.Ref AS Ref
	|FROM
	|	Catalog.ContactPersons AS ContactPersons
	|WHERE
	|	ContactPersons.Owner = &Counterparty";
	
	Query.SetParameter("Counterparty", Counterparty);
	
	Selection = Query.Execute().Select();
	While Selection.Next() Do
		If RecipientsOwners.Find(Selection.Ref) = Undefined Then
			RecipientsOwners.Add(Selection.Ref);
		EndIf;
	EndDo;
	
EndProcedure

#EndRegion