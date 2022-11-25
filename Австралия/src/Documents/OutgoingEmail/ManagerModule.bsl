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

// StandardSubsystems.BatchObjectsModification

// Returns object attributes allowed to be edited using batch attribute change data processor.
// 
//
// Returns:
//  Array - a list of object attribute names.
Function AttributesToEditInBatchProcessing() Export
	
	Result = New Array;
	Result.Add("Importance");
	Result.Add("EmployeeResponsible");
	Result.Add("InteractionBasis");
	Result.Add("Comment");
	Result.Add("EmailRecipients.Presentation");
	Result.Add("EmailRecipients.Contact");
	Result.Add("CCRecipients.Presentation");
	Result.Add("CCRecipients.Contact");
	Result.Add("ReplyRecipients.Presentation");
	Result.Add("ReplyRecipients.Contact");
	Result.Add("BccRecipients.Presentation");
	Result.Add("BccRecipients.Contact");
	Return Result;
	
EndFunction

// End StandardSubsystems.BatchObjectsModification

// StandardSubsystems.Interactions

// Gets email addressees.
//
// Parameters:
//  Ref - DocumentRef.OutgoingEmail - a document whose subscriber is to be received.
//
// Returns:
//   ValueTable - a table that contains the Contact, Presentation, and Address columns.
//
Function GetContacts(Ref) Export
	
	QueryText = 
	"SELECT
	|	EmailMessageOutgoingMessageRecipients.Address,
	|	EmailMessageOutgoingMessageRecipients.Presentation,
	|	EmailMessageOutgoingMessageRecipients.Contact
	|FROM
	|	Document.OutgoingEmail.EmailRecipients AS EmailMessageOutgoingMessageRecipients
	|WHERE
	|	EmailMessageOutgoingMessageRecipients.Ref = &Ref
	|
	|UNION ALL
	|
	|SELECT
	|	EmailMessageOutgoingCCRecipients.Address,
	|	EmailMessageOutgoingCCRecipients.Presentation,
	|	EmailMessageOutgoingCCRecipients.Contact
	|FROM
	|	Document.OutgoingEmail.CCRecipients AS EmailMessageOutgoingCCRecipients
	|WHERE
	|	EmailMessageOutgoingCCRecipients.Ref = &Ref
	|
	|UNION ALL
	|
	|SELECT
	|	EmailMessageOutgoingResponseRecipients.Address,
	|	EmailMessageOutgoingResponseRecipients.Presentation,
	|	EmailMessageOutgoingResponseRecipients.Contact
	|FROM
	|	Document.OutgoingEmail.ReplyRecipients AS EmailMessageOutgoingResponseRecipients
	|WHERE
	|	EmailMessageOutgoingResponseRecipients.Ref = &Ref
	|
	|UNION ALL
	|
	|SELECT
	|	EmailMessageOutgoingBCCRecipients.Address,
	|	EmailMessageOutgoingBCCRecipients.Presentation,
	|	EmailMessageOutgoingBCCRecipients.Contact
	|FROM
	|	Document.OutgoingEmail.BccRecipients AS EmailMessageOutgoingBCCRecipients
	|WHERE
	|	EmailMessageOutgoingBCCRecipients.Ref = &Ref";
	
	Query = New Query;
	Query.Text = QueryText;
	Query.SetParameter("Ref", Ref);
	ContactsTable = Query.Execute().Unload();
	
	Return Interactions.ConvertContactsTableToArray(ContactsTable);
	
EndFunction

// End StandardSubsystems.Interactions

// StandardSubsystems.AccessManagement

// See AccessManagementOverridable.OnFillListsWithAccessRestriction. 
Procedure OnFillAccessRestriction(Restriction) Export
	
	Restriction.Text =
	"AllowReadUpdate
	|WHERE
	|	ValueAllowed(EmployeeResponsible, Disabled AS False)
	|	OR ValueAllowed(Author, Disabled AS False)
	|	OR ValueAllowed(Account, Disabled AS False)";
	
EndProcedure

// End StandardSubsystems.AccessManagement

// StandardSubsystems.AttachableCommands

// Defined the list of commands for creating on the basis.
//
// Parameters:
//  GenerationCommands - ValueTable - see GenerationOverridable.BeforeAddGenerationCommands. 
//  Parameters - Structure - see GenerationOverridable.BeforeAddGenerationCommands. 
//
Procedure AddGenerationCommands(GenerationCommands, Parameters) Export
	
	Documents.Meeting.AddGenerateCommand(GenerationCommands);
	Documents.PlannedInteraction.AddGenerateCommand(GenerationCommands);
	Documents.SMSMessage.AddGenerateCommand(GenerationCommands);
	Documents.PhoneCall.AddGenerateCommand(GenerationCommands);
	
EndProcedure

// Use this procedure in the AddGenerationCommands procedure of other object manager modules.
// Adds this object to the list of object generation commands.
//
// Parameters:
//  GenerationCommands - ValueTable - see GenerationOverridable.BeforeAddGenerationCommands. 
//
// Returns:
//  ValueTableRow, Undefined - details of the added command.
//
Function AddGenerateCommand(GenerationCommands) Export
	
	Return Generate.AddGenerationCommand(GenerationCommands, Metadata.Documents.OutgoingEmail);
	
EndFunction

// End StandardSubsystems.AttachableCommands

#EndRegion

#EndRegion

#Region EventHandlers

Procedure ChoiceDataGetProcessing(ChoiceData, Parameters, StandardProcessing)
	
	InteractionsEvents.ChoiceDataGetProcessing(Metadata.Documents.OutgoingEmail.Name,
		ChoiceData, Parameters, StandardProcessing);
	
EndProcedure

#EndRegion

#Region Private

#Region UpdateHandlers

// Registers the objects to be updated to the latest version in the InfobaseUpdate exchange plan.
// 
//
Procedure RegisterDataToProcessForMigrationToNewVersion(Parameters) Export
	
	QueryText ="
	|SELECT
	|	OutgoingEmail.Ref AS Ref
	|FROM
	|	Document.OutgoingEmail AS OutgoingEmail
	|WHERE
	|	OutgoingEmail.DeleteMessageIDSendIMAP <> """"
	|
	|UNION 
	|
	|SELECT
	|	DocumentTable.Ref AS Ref
	|FROM
	|	DocumentJournal.Interactions AS Interactions
	|		INNER JOIN Document.OutgoingEmail AS DocumentTable
	|		ON Interactions.MessageID = DocumentTable.BasisID
	|			AND Interactions.Account = DocumentTable.Account
	|			AND Interactions.Ref <> DocumentTable.InteractionBasis
	|			AND (Interactions.MessageID <> """")
	|			AND (DocumentTable.InteractionBasis <> """")";
	
	Query = New Query(QueryText);
	Query.SetParameter("Date", Date(2016, 7, 1));
	
	InfobaseUpdate.MarkForProcessing(Parameters, Query.Execute().Unload().UnloadColumn("Ref"));
	
EndProcedure

// Update handler for version 2.3.6.69:
// - moves data on the IMAP email ID from one attribute to another to
// - prevent information loss upon update to new releases.
//
Procedure ProcessDataForMigrationToNewVersion(Parameters) Export
	
	FullObjectName = "Document.OutgoingEmail";
	
	Query = New Query;
	Query.Text = "
	|SELECT
	|	DocumentTable.Ref AS Ref,
	|	Interactions.Ref AS EmailBasis,
	|	CASE
	|		WHEN Interactions.Ref IS NULL
	|			THEN FALSE
	|		ELSE TRUE
	|	END AS SpecifyBasisEmailRequired,
	|	DocumentTable.DeleteMessageIDSendIMAP AS DeleteMessageIDSendIMAP
	|FROM
	|	&TTDocumentsToProcess AS ReferencesToProcess
	|		LEFT JOIN Document.OutgoingEmail AS DocumentTable
	|		ON (DocumentTable.Ref = ReferencesToProcess.Ref)
	|		LEFT JOIN DocumentJournal.Interactions AS Interactions
	|		ON (Interactions.MessageID = DocumentTable.BasisID)
	|			AND (Interactions.Account = DocumentTable.Account)
	|			AND (Interactions.Ref <> DocumentTable.InteractionBasis)
	|			AND (Interactions.MessageID <> """")
	|			AND (DocumentTable.InteractionBasis <> """")";
	
	TempTablesManager = New TempTablesManager;
	Result = InfobaseUpdate.CreateTemporaryTableOfRefsToProcess(Parameters.Queue, FullObjectName, TempTablesManager);
	If NOT Result.HasDataToProcess Then
		Parameters.ProcessingCompleted = True;
		Return;
	EndIf;
	If NOT Result.HasRecordsInTemporaryTable Then
		Parameters.ProcessingCompleted = False;
		Return;
	EndIf; 
	
	Query.Text = StrReplace(Query.Text, "&TTDocumentsToProcess", Result.TempTableName);
	Query.TempTablesManager = TempTablesManager;
	
	ObjectsToProcess = Query.Execute().Select();
	
	While ObjectsToProcess.Next() Do
		
		BeginTransaction();
		
		Try
			
			// Setting a managed lock to post object responsible reading.
			Lock = New DataLock;
			
			LockItem = Lock.Add(FullObjectName);
			LockItem.SetValue("Ref", ObjectsToProcess.Ref);
			
			Lock.Lock();
			
			Object = ObjectsToProcess.Ref.GetObject();
			
			If Object = Undefined Then
				InfobaseUpdate.MarkProcessingCompletion(ObjectsToProcess.Ref);
			Else
				
				If ValueIsFilled(ObjectsToProcess.DeleteMessageIDSendIMAP) Then
					Object.MessageIDIMAPSending        = Object.DeleteMessageIDSendIMAP;
					Object.DeleteMessageIDSendIMAP = "";
				EndIf;
				
				If ObjectsToProcess.SpecifyBasisEmailRequired Then
					
					Object.InteractionBasis = ObjectsToProcess.EmailBasis;
					
				EndIf;
			
				InfobaseUpdate.WriteData(Object);
			EndIf;
			
			CommitTransaction();
			
		Except
			
			RollbackTransaction();
			
			ObjectMetadata = Metadata.FindByFullName(FullObjectName);
			
			MessageText = NStr("ru = 'Не удалось обработать %ObjectName%: %Ref% по причине: %Reason%'; en = 'Cannot process %ObjectName%: %Ref% for the reason: %Reason%'; pl = 'Nie można przetworzyź %ObjectName%: %Ref% po przyczynie: %Reason%';es_ES = 'No se ha podido procesar %ObjectName%: %Ref% por la causa: %Reason%';es_CO = 'No se ha podido procesar %ObjectName%: %Ref% por la causa: %Reason%';tr = '%ObjectName% işlenemiyor: %Ref%, nedeni: %Reason%';it = 'Impossibile processare %ObjectName%: %Ref% a causa di: %Reason%';de = 'Kann %ObjectName%: %Ref% wegen: %Reason% nicht bearbeiten'");
			MessageText = StrReplace(MessageText, "%ObjectName%", FullObjectName);
			MessageText = StrReplace(MessageText, "%Ref%",     ObjectsToProcess.Ref);
			MessageText = StrReplace(MessageText, "%Reason%",    DetailErrorDescription(ErrorInfo()));
			
			WriteLogEvent(InfobaseUpdate.EventLogEvent(),
										EventLogLevel.Warning,
										ObjectMetadata,
										ObjectsToProcess.Ref,
										MessageText);
			
		EndTry;
		
	EndDo;
	
	Parameters.ProcessingCompleted = InfobaseUpdate.DataProcessingCompleted(Parameters.Queue, FullObjectName);
	
EndProcedure

#EndRegion

#EndRegion

#EndIf
