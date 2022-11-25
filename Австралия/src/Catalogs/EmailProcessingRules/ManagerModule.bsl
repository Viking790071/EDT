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

// Returns the object attributes that are not recommended to be edited using batch attribute 
// modification data processor.
//
// Returns:
//  Array - a list of object attribute names.
Function AttributesToSkipInBatchProcessing() Export
	
	Result = New Array;
	Result.Add("Code");
	Result.Add("Description");
	Result.Add("SettingsComposer");
	Result.Add("PutInFolder");
	Result.Add("AddlOrderingAttribute");
	Result.Add("FilterPresentation");
	Return Result;
	
EndFunction

// End StandardSubsystems.BatchObjectsModification

// StandardSubsystems.AccessManagement

// See AccessManagementOverridable.OnFillListsWithAccessRestriction. 
Procedure OnFillAccessRestriction(Restriction) Export
	
	Restriction.Text =
	"AllowReadUpdate
	|WHERE
	|	ValueAllowed(Owner)
	|	OR ValueAllowed(Owner.AccountOwner, EmptyRef AS False)";
	
EndProcedure

// End StandardSubsystems.AccessManagement

#EndRegion

#EndRegion

#Region Internal

// Applies email processing rules.
//
// Parameters:
//  ExportParameters - Structure - contains the following fields.
//                 - ForEmailsInFolder     - Catalog.EmailsFolders - emails stored in the folder
//                 will be processed.
//                 - IncludingSubordinateFolders - Boolean - shows that emails in subordinate folders must be processed.
//                 - RulesTable      - ValueTable - a table of rules that must be applied.
//  StorageAddress - String -             - a message about the rule application result.
//
Procedure ApplyRules(ExportParameters, StorageAddress) Export
	
	MapsTable = New ValueTable;
	MapsTable.Columns.Add("Folder");
	MapsTable.Columns.Add("Email");
	
	ConditionTextByFolder = ?(ExportParameters.IncludeSubordinateSubsystems," IN HIERARCHY(&EmailMessageFolder) "," = &EmailMessageFolder ");
	
	Query = New Query;
	Query.Text = "SELECT
	|	SelectedRules.Rule,
	|	SelectedRules.Apply
	|INTO SelectedRules
	|FROM
	|	&SelectedRules AS SelectedRules
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	SelectedRules.Rule,
	|	EmailProcessingRules.SettingsComposer,
	|	EmailProcessingRules.PutInFolder
	|FROM
	|	SelectedRules AS SelectedRules
	|		INNER JOIN Catalog.EmailProcessingRules AS EmailProcessingRules
	|		ON SelectedRules.Rule = EmailProcessingRules.Ref
	|WHERE
	|	SelectedRules.Apply
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT DISTINCT
	|	IncomingEmail.Ref,
	|	InteractionsFolderSubjects.EmailMessageFolder AS Folder
	|FROM
	|	Document.IncomingEmail AS IncomingEmail
	|		LEFT JOIN InformationRegister.InteractionsFolderSubjects AS InteractionsFolderSubjects
	|		ON InteractionsFolderSubjects.Interaction = IncomingEmail.Ref
	|WHERE
	|	InteractionsFolderSubjects.EmailMessageFolder " + ConditionTextByFolder +"
	|
	|UNION ALL
	|
	|SELECT
	|	OutgoingEmail.Ref,
	|	InteractionsFolderSubjects.EmailMessageFolder
	|FROM
	|	Document.OutgoingEmail AS OutgoingEmail
	|		LEFT JOIN InformationRegister.InteractionsFolderSubjects AS InteractionsFolderSubjects
	|		ON InteractionsFolderSubjects.Interaction = OutgoingEmail.Ref
	|WHERE
	|	InteractionsFolderSubjects.EmailMessageFolder " + ConditionTextByFolder ;
	
	Query.SetParameter("SelectedRules", ExportParameters.RulesTable);
	Query.SetParameter("EmailMessageFolder", ExportParameters.ForEmailsInFolder);
	
	Result = Query.ExecuteBatch();
	If Result[2].IsEmpty() Then
		MessageText = NStr("ru = 'В выбранной папке нет писем.'; en = 'The selected folder is empty.'; pl = 'Wybrany folder jest pusty.';es_ES = 'La carpeta seleccionada está vacía.';es_CO = 'La carpeta seleccionada está vacía.';tr = 'Seçilen klasör boş.';it = 'La cartella selezionata è vuota.';de = 'Der ausgewählte Ordner ist leer.'");
		PutToTempStorage(MessageText, StorageAddress);
		Return;
	EndIf;
	
	EmailsTable = Result[2].Unload();
	EmailsArray  = EmailsTable.UnloadColumn("Ref");
	FoldersArray  = EmailsTable.UnloadColumn("Folder");
	FoldersArray  = Interactions.DeleteDuplicateElementsFromArray(FoldersArray);
	
	Selection = Result[1].Select();
	While Selection.Next() Do
		
		ProcessingRulesSchema = GetTemplate("EmailProcessingRuleScheme");
		
		TemplateComposer = New DataCompositionTemplateComposer();
		SettingsComposer = New DataCompositionSettingsComposer;
		SettingsComposer.Initialize(New DataCompositionAvailableSettingsSource(ProcessingRulesSchema));
		SettingsComposer.LoadSettings(Selection.SettingsComposer.Get());
		SettingsComposer.Refresh(DataCompositionSettingsRefreshMethod.CheckAvailability);
		CommonClientServer.SetFilterItem(SettingsComposer.Settings.Filter,
			"Ref",EmailsArray,DataCompositionComparisonType.InList);
		CommonClientServer.SetFilterItem(SettingsComposer.Settings.Filter,
			"Ref.Account",ExportParameters.Account,DataCompositionComparisonType.Equal);
		
		DataCompositionTemplate = TemplateComposer.Execute(ProcessingRulesSchema,
			SettingsComposer.GetSettings(),,,Type("DataCompositionValueCollectionTemplateGenerator"));
		
		QueryText = DataCompositionTemplate.DataSets.MainDataSet.Query;
		QueryRule = New Query(QueryText);
		For each Parameter In DataCompositionTemplate.ParameterValues Do
			QueryRule.Parameters.Insert(Parameter.Name, Parameter.Value);
		EndDo;
		
		EmailResult = QueryRule.Execute();
		If Not EmailResult.IsEmpty() Then
			EmailSelection = EmailResult.Select();
			While EmailSelection.Next() Do
				
				NewTableRow = MapsTable.Add();
				NewTableRow.Folder = Selection.PutInFolder;
				NewTableRow.Email = EmailSelection.Ref;
				
				ArrayElementIndexForDeletion = EmailsArray.Find(EmailSelection.Ref);
				If ArrayElementIndexForDeletion <> Undefined Then
					EmailsArray.Delete(ArrayElementIndexForDeletion);
				EndIf;
			EndDo;
		EndIf;
		
	EndDo;
	
	For each TableRow In MapsTable Do
		Interactions.SetEmailFolder(TableRow.Email, TableRow.Folder, False);
		If ValueIsFilled(TableRow.Folder) AND FoldersArray.Find(TableRow.Folder) = Undefined Then
			 FoldersArray.Add(TableRow.Folder);
		EndIf;
	EndDo;
		
	Interactions.CalculateReviewedByFolders(Interactions.TableOfDataForReviewedCalculation(FoldersArray, "Folder"));
	
	If MapsTable.Count() > 0 Then
		MessageText = NStr("ru = 'Перенос писем в папки выполнен.'; en = 'The mail messages are moved to the folders.'; pl = 'Wiadomości są przeniesione do folderuów.';es_ES = 'Los mensajes de correo se mueven a las carpetas.';es_CO = 'Los mensajes de correo se mueven a las carpetas.';tr = 'Posta iletileri klasörlere taşındı.';it = 'I messaggi mail sono spostati nelle cartelle.';de = 'Die Mail-Nachrichten sind zu den Ordnern verschieben.'");
	Else
		MessageText =  NStr("ru = 'Ни одно письмо не было перенесено'; en = 'No mail messages are moved.'; pl = 'Nie przeniesiono żadnej wiadomości e-mail.';es_ES = 'Ningún mensaje de correo ha sido movido.';es_CO = 'Ningún mensaje de correo ha sido movido.';tr = 'Hiçbir ileti taşınmadı.';it = 'Nessun messaggio mail spostato.';de = 'Keine Mail-Nachrichten wurden verschieben.'");
	EndIf;
	
	PutToTempStorage(MessageText, StorageAddress);
	
EndProcedure

#EndRegion

#EndIf
