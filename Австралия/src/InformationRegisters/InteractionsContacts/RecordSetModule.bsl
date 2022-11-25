///////////////////////////////////////////////////////////////////////////////////////////////////////
// Copyright (c) 2019, 1C-Soft LLC
// All Rights reserved. This application and supporting materials are provided under the terms of 
// Attribution 4.0 International license (CC BY 4.0)
// The license text is available at:
// https://creativecommons.org/licenses/by/4.0/legalcode
///////////////////////////////////////////////////////////////////////////////////////////////////////

#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region EventHandlers

Procedure BeforeWrite(Cancel, Replacing)
	
	If DataExchange.Load Then
		Return;
	EndIf;
	
	If NOT Interactions.CalculateReviewedItems(AdditionalProperties) Then
		Return;
	EndIf;
	
	Query = New Query;
	Query.Text = "
	|SELECT
	|	InteractionsContacts.Contact
	|FROM
	|	InformationRegister.InteractionsContacts AS InteractionsContacts
	|WHERE
	|	InteractionsContacts.Interaction = &Interaction";
	
	Query.SetParameter("Interaction", Filter.Interaction.Value);
	AdditionalProperties.Insert("RecordTable",  Query.Execute().Unload());
	
EndProcedure

Procedure OnWrite(Cancel, Replacing)
	
	If DataExchange.Load Then
		Return;
	EndIf;
	
	If NOT Interactions.CalculateReviewedItems(AdditionalProperties) Then
		Return;
	EndIf;
	
	Query = New Query;
	Query.Text = "
	|SELECT
	|	OldSet.Contact AS Contact
	|INTO OldSet
	|FROM
	|	&OldSet AS OldSet
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	InteractionsContacts.Contact AS Contact
	|INTO NewSet
	|FROM
	|	InformationRegister.InteractionsContacts AS InteractionsContacts
	|WHERE
	|	InteractionsContacts.Interaction = &Interaction
	|
	|INDEX BY
	|	Contact
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	NewSet.Contact AS CalculateBy
	|FROM
	|	NewSet AS NewSet
	|
	|UNION
	|
	|SELECT
	|	OldSet.Contact
	|FROM
	|	OldSet AS OldSet";
	
	Query.SetParameter("OldSet", AdditionalProperties.RecordTable);
	Query.SetParameter("Interaction", Filter.Interaction.Value);
	Interactions.CalculateReviewedByContacts(Query.Execute().Unload());
	
EndProcedure

#EndRegion

#Else
Raise NStr("ru = 'Недопустимый вызов объекта на клиенте.'; en = 'Invalid object call on the client.'; pl = 'Niepoprawne wywołanie obiektu na kliencie.';es_ES = 'Invalidar la llamada de objeto al cliente.';es_CO = 'Invalidar la llamada de objeto al cliente.';tr = 'İstemcide geçersiz nesne çağrısı.';it = 'Chiamata oggetto non valida per il client.';de = 'Ungültiger Objektaufruf auf dem Client.'");
#EndIf