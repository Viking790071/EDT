///////////////////////////////////////////////////////////////////////////////////////////////////////
// Copyright (c) 2019, 1C-Soft LLC
// All Rights reserved. This application and supporting materials are provided under the terms of 
// Attribution 4.0 International license (CC BY 4.0)
// The license text is available at:
// https://creativecommons.org/licenses/by/4.0/legalcode
///////////////////////////////////////////////////////////////////////////////////////////////////////

#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region Public

#Region ForCallsFromOtherSubsystems

// StandardSubsystems.Interactions

// The procedure generates participant list rows.
//
// Parameters:
//  Contacts - Array - an array containing interaction participants.
//
Procedure FillContacts(Contacts) Export
	
	If Not Interactions.ContactsFilled(Contacts) Then
		Return;
	EndIf;
	
	// Moving the first contact to the phone call.
	Parameter = Contacts[0];
	If TypeOf(Parameter) = Type("Structure") Then
		SubscriberContact       = Parameter.Contact;
		HowToContactSubscriber  = Parameter.Address;
		SubscriberPresentation = Parameter.Presentation;
	Else
		SubscriberContact = Parameter;
	EndIf;
	
	Interactions.FinishFillingContactsFields(SubscriberContact, SubscriberPresentation, 
		HowToContactSubscriber, Enums.ContactInformationTypes.Phone);
	
EndProcedure

// End StandardSubsystems.Interactions

// StandardSubsystems.AccessManagement

// See AccessManagement.FillAccessValuesSets. 
//
// Parameters:
//   Table - ValueTable - see AccessManagement.AccessValuesSetsTable. 
//
Procedure FillAccessValuesSets(Table) Export
	
	InteractionsEvents.FillAccessValuesSets(ThisObject, Table);
	
EndProcedure

// End StandardSubsystems.AccessManagement

#EndRegion

#EndRegion

#Region EventHandlers

Procedure Filling(FillingData, FillingText, StandardProcessing)
	
	Interactions.FillDefaultAttributes(ThisObject, FillingData);
	
EndProcedure

Procedure BeforeWrite(Cancel, WriteMode, PostingMode)
	
	If DataExchange.Load Then
		Return;
	EndIf;
	
EndProcedure

Procedure OnCopy(CopiedObject)
	
	EmployeeResponsible    = Users.CurrentUser();
	Author            = Users.CurrentUser();
	
EndProcedure

Procedure OnWrite(Cancel)
	
	If DataExchange.Load Then
		Return;
	EndIf;
	
	Interactions.OnWriteDocument(ThisObject);
	
EndProcedure

#EndRegion

#Else
Raise NStr("ru = 'Недопустимый вызов объекта на клиенте.'; en = 'Invalid object call on the client.'; pl = 'Niepoprawne wywołanie obiektu na kliencie.';es_ES = 'Invalidar la llamada de objeto al cliente.';es_CO = 'Invalidar la llamada de objeto al cliente.';tr = 'İstemcide geçersiz nesne çağrısı.';it = 'Chiamata oggetto non valida per il client.';de = 'Ungültiger Objektaufruf auf dem Client.'");
#EndIf