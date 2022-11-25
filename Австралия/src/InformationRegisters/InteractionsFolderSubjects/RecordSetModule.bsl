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
	
	AdditionalProperties.Insert("RecordStructure", RecordStructure());
	
EndProcedure

Procedure OnWrite(Cancel, Replacing)
	
	If DataExchange.Load Then
		Return;
	EndIf;
	
	If NOT Interactions.CalculateReviewedItems(AdditionalProperties) Then
		Return;
	EndIf;
	
	OldRecord     = AdditionalProperties.RecordStructure;
	NewRecord      = RecordStructure();
	DataForCalculation = New Structure("NewRecord, OldRecord", NewRecord, OldRecord);
	
	If NewRecord.Reviewed <> OldRecord.Reviewed Then
		
		Interactions.CalculateReviewedByFolders(Interactions.TableOfDataForReviewedCalculation(DataForCalculation, "Folder"));
		Interactions.CalculateReviewedBySubjects(Interactions.TableOfDataForReviewedCalculation(DataForCalculation, "Topic"));
		
		Return;

	EndIf;
	
	If NewRecord.Folder <> OldRecord.Folder Then
		
		Interactions.CalculateReviewedByFolders(Interactions.TableOfDataForReviewedCalculation(DataForCalculation, "Folder"));
		
		Return;
		
	EndIf;
	
	If NewRecord.Topic <> OldRecord.Topic Then
		
		Interactions.CalculateReviewedBySubjects(Interactions.TableOfDataForReviewedCalculation(DataForCalculation, "Topic"));
		Return;
		
	EndIf;
	
EndProcedure

#EndRegion

#Region Private

Function RecordStructure()

	ReturnStructure = New Structure;
	ReturnStructure.Insert("Topic", Undefined);
	ReturnStructure.Insert("Folder", Catalogs.EmailMessageFolders.EmptyRef());
	ReturnStructure.Insert("Reviewed", Undefined);
	
	If Filter.Count() = 0 Then
		Return Undefined;
	EndIf;
	
	Query = New Query;
	Query.Text = "SELECT
	|	InteractionsFolderSubjects.Topic,
	|	InteractionsFolderSubjects.EmailMessageFolder AS Folder,
	|	InteractionsFolderSubjects.Reviewed
	|FROM
	|	InformationRegister.InteractionsFolderSubjects AS InteractionsFolderSubjects
	|WHERE
	|	InteractionsFolderSubjects.Interaction = &Interaction";
	
	Query.SetParameter("Interaction", Filter.Interaction.Value);
	
	Result = Query.Execute();
	If Result.IsEmpty() Then
		Return ReturnStructure;
	EndIf;
	
	Selection = Result.Select();
	Selection.Next();
	FillPropertyValues(ReturnStructure, Selection);
	Return ReturnStructure;
	
EndFunction

#EndRegion

#Else
Raise NStr("ru = 'Недопустимый вызов объекта на клиенте.'; en = 'Invalid object call on the client.'; pl = 'Niepoprawne wywołanie obiektu na kliencie.';es_ES = 'Invalidar la llamada de objeto al cliente.';es_CO = 'Invalidar la llamada de objeto al cliente.';tr = 'İstemcide geçersiz nesne çağrısı.';it = 'Chiamata oggetto non valida per il client.';de = 'Ungültiger Objektaufruf auf dem Client.'");
#EndIf