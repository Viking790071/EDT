#Region Public

// Returns description of the print form found in the collection.
// If the description is not found, returns Undefined.
// The function is used only inside the Print procedure.
//
// Parameters:
//  PrintFormsCollection - ValueTable - an internal parameter passed to the Print procedure.
//  ID - String - a print form ID.
//
// Returns:
//  ValueTableRow - found description of the print form.
Function PrintFormInfo(PrintFormsCollection, ID) Export
	Return PrintFormsCollection.Find(Upper(ID), "UpperCaseName");
EndFunction

// Checks whether printing of a template is required.
// The function is used only inside the Print procedure.
//
// Parameters:
//  PrintFormsCollection - ValueTable - an internal parameter passed to the Print procedure.
//  TemplateName - String - a name of the template being checked.
//
// Returns:
//  Boolean - True, if the template requires printing.
Function TemplatePrintRequired(PrintFormsCollection, TemplateName) Export
	
	Return PrintFormsCollection.Find(Upper(TemplateName), "UpperCaseName") <> Undefined;
	
EndFunction

// Adds a spreadsheet document to a print form collection.
// The procedure is used only inside the Print procedure.
//
// Parameters:
//  PrintFormsCollection - ValueTable - an internal parameter passed to the Print procedure.
//  TemplateName - String - a template name.
//  TemplateSynonym - String - a template presentation.
//  SpreadsheetDocument - SpreadsheetDocument - a document print form.
//  Picture - Picture - a print form icon.
//  FullPathToTemplate - String - a path to the template in the metadata tree, for example:
//                                   "Document.ProformaInvoice.PF_MXL_InvoiceOrder".
//                                   If you do not specify this parameter, editing the template in 
//                                   the PrintDocuments form is not available to users.
//  PrintFormFileName - String - a name used when saving a print form to a file.
//                        - Map:
//                           * Key - AnyRef - a reference to the print object.
//                           * Value - String - a file name.
Procedure OutputSpreadsheetDocumentToCollection(PrintFormsCollection, TemplateName, TemplateSynonym, SpreadsheetDocument,
	Picture = Undefined, FullPathToTemplate = "", PrintFormFileName = Undefined) Export
	
	PrintFormDetails = PrintFormsCollection.Find(Upper(TemplateName), "UpperCaseName");
	If PrintFormDetails <> Undefined Then
		PrintFormDetails.SpreadsheetDocument = SpreadsheetDocument;
		PrintFormDetails.TemplateSynonym = TemplateSynonym;
		PrintFormDetails.Picture = Picture;
		PrintFormDetails.FullPathToTemplate = FullPathToTemplate;
		PrintFormDetails.PrintFormFileName = PrintFormFileName;
	EndIf;
	
EndProcedure

// Sets an object printing area in a spreadsheet document.
// Used to connect an area in a spreadsheet document to a print object (reference).
// The procedure is called when generating the next print form area in a spreadsheet document.
// 
//
// Parameters:
//  SpreadsheetDocument - SpreadsheetDocument - a print form.
//  RowNumberStart - Number - a position of the beginning of the next area in the document.
//  PrintObjects - ValueList - a print object list.
//  Ref - AnyRef - a print object.
Procedure SetDocumentPrintArea(SpreadsheetDocument, RowNumberStart, PrintObjects, Ref) Export
	
	Item = PrintObjects.FindByValue(Ref);
	If Item = Undefined Then
		AreaName = "Document_" + Format(PrintObjects.Count() + 1, "NZ=; NG=");
		PrintObjects.Add(Ref, AreaName);
	Else
		AreaName = Item.Presentation;
	EndIf;
	
	RowNumberEnd = SpreadsheetDocument.TableHeight;
	SpreadsheetDocument.Area(RowNumberStart, , RowNumberEnd, ).Name = AreaName;

EndProcedure

// Returns an external print form list.
//
// Parameters:
//  FullMetadataObjectName - String - a full name of the metadata object to obtain the list of print 
//                                        forms for.
//
// Returns:
//  ValueList - a collection of print forms:
//   * Value - String - a print form ID.
//   * Presentation - String - a print form presentation.
Function PrintFormsListFromExternalSources(FullMetadataObjectName) Export
	
	ExternalPrintForms = New ValueList;
	If Not IsBlankString(FullMetadataObjectName) Then
		If Common.SubsystemExists("StandardSubsystems.AdditionalReportsAndDataProcessors") Then
			ModuleAdditionalReportsAndDataProcessors = Common.CommonModule("AdditionalReportsAndDataProcessors");
			ModuleAdditionalReportsAndDataProcessors.OnReceiveExternalPrintFormList(ExternalPrintForms, FullMetadataObjectName);
		EndIf;
	EndIf;
	
	Return ExternalPrintForms;
	
EndFunction

// Returns a list of print commands for the specified print form.
//
// Parameters:
//  Form - ClientApplicationForm, String - a form or a full form name for getting a list of print commands.
//  ObjectsList - Array - a collection of metadata objects whose print commands are to be used when 
//                            drawing up a list of print commands for the specified form.
// Returns:
//  ValueTable - see description in CreatePrintCommandsCollection().
//
Function FormPrintCommands(Form, ObjectsList = Undefined) Export
	
	If TypeOf(Form) = Type("ClientApplicationForm") Then
		FormName = Form.FormName;
	Else
		FormName = Form;
	EndIf;
	
	MetadataObject = Metadata.FindByFullName(FormName);
	If MetadataObject <> Undefined AND Not Metadata.CommonForms.Contains(MetadataObject) Then
		MetadataObject = MetadataObject.Parent();
	Else
		MetadataObject = Undefined;
	EndIf;

	If MetadataObject <> Undefined Then
		MORef = Common.MetadataObjectID(MetadataObject);
	EndIf;
	
	PrintCommands = CreatePrintCommandsCollection();
	
	StandardProcessing = True;
	PrintManagementOverridable.BeforeAddPrintCommands(FormName, PrintCommands, StandardProcessing);
	
	If StandardProcessing Then
		If ObjectsList <> Undefined Then
			FillPrintCommandsForObjectsList(ObjectsList, PrintCommands);
		ElsIf MetadataObject = Undefined Then
			Return PrintCommands;
		Else
			IsDocumentJournal = Common.IsDocumentJournal(MetadataObject);
			ListSettings = New Structure;
			ListSettings.Insert("PrintCommandsManager", Common.ObjectManagerByFullName(MetadataObject.FullName()));
			ListSettings.Insert("AutoFilling", IsDocumentJournal);
			If IsDocumentJournal Then
				PrintManagementOverridable.OnGetPrintCommandListSettings(ListSettings);
			EndIf;
			
			If ListSettings.AutoFilling Then
				If IsDocumentJournal Then
					FillPrintCommandsForObjectsList(MetadataObject.RegisteredDocuments, PrintCommands);
				EndIf;
			Else
				PrintManager = Common.ObjectManagerByFullName(MetadataObject.FullName());
				PrintCommandsToAdd = CreatePrintCommandsCollection();
				PrintManager.AddPrintCommands(PrintCommandsToAdd);
				
				For Each PrintCommand In PrintCommandsToAdd Do
					If PrintCommand.PrintManager = Undefined Then
						PrintCommand.PrintManager = MetadataObject.FullName();
					EndIf;
					FillPropertyValues(PrintCommands.Add(), PrintCommand);
				EndDo;
				
				If Common.SubsystemExists("StandardSubsystems.AdditionalReportsAndDataProcessors") Then
					ModuleAdditionalReportsAndDataProcessors = Common.CommonModule("AdditionalReportsAndDataProcessors");
					ModuleAdditionalReportsAndDataProcessors.OnReceivePrintCommands(PrintCommands, MetadataObject.FullName());
				EndIf;
				
				AttachedReportsAndDataProcessors = AttachableCommands.AttachedObjects(MORef);
				FoundItems = AttachedReportsAndDataProcessors.FindRows(New Structure("AddPrintCommands", True));
				For Each AttachedObject In FoundItems Do
					AttachedObject.Manager.AddPrintCommands(PrintCommands);
					AddedCommands = PrintCommands.FindRows(New Structure("PrintManager", Undefined));
					For Each Command In AddedCommands Do
						Command.PrintManager = AttachedObject.FullName;
					EndDo;
				EndDo;
			EndIf;
		EndIf;
	EndIf;
	
	For Each PrintCommand In PrintCommands Do
		If PrintCommand.Order = 0 Then
			PrintCommand.Order = 50;
		EndIf;
		PrintCommand.AdditionalParameters.Insert("AddExternalPrintFormsToSet", PrintCommand.AddExternalPrintFormsToSet);
	EndDo;
	
	If MetadataObject <> Undefined Then
		SetPrintCommandsSettings(PrintCommands, MORef);
	EndIf;
	
	PrintCommands.Sort("Order Asc, Presentation Asc");
	
	NameParts = StrSplit(FormName, ".");
	ShortFormName = NameParts[NameParts.Count()-1];
	
	// Filter by form names
	For RowNumber = -PrintCommands.Count() + 1 To 0 Do
		PrintCommand = PrintCommands[-RowNumber];
		FormsList = StrSplit(PrintCommand.FormsList, ",", False);
		If FormsList.Count() > 0 AND FormsList.Find(ShortFormName) = Undefined Then
			PrintCommands.Delete(PrintCommand);
		EndIf;
	EndDo;
	
	DefinePrintCommandsVisibilityByFunctionalOptions(PrintCommands, Form);
	
	Return PrintCommands;
	
EndFunction

// Creates a blank table with description of print commands.
// The table of print commands is passed to the AddPrintCommands procedures placed in the 
// configuration object manager modules listed in the procedure
// PrintManagerOverridable.OnDefineObjectsWithPrintCommands.
// 
// Returns:
//  ValueTable - description of print commands:
//
//  * ID - String - a print command ID. The print manager uses this ID to determine the print form 
//                             that must be generated.
//                             Example: "InvoiceOrder".
//
//                                        To print multiple print forms, you can specify all their 
//                                        IDs at once (as a comma-separated string or an array of strings), for example:
//                                         "InvoiceOrder,LetterOfGuarantee".
//
//                                        To set a number of copies for a print form, duplicate its 
//                                        ID as many times as the number of copies you want 
//                                        generated. Note. The order of print forms in the set 
//                                        matches the order of print form IDs specified in this 
//                                        parameter. Example (2 proforma invoices + 1 letter of guarantee):
//                                        "InvoiceOrder,InvoiceOrder,LetterOfGuarantee".
//
//                                        A print form ID can contain an alternative print manager 
//                                        if it is different from the print manager specified in the 
//                                         PrintManager parameter, for example: "InvoiceOrder,Processing.PrintForm.LetterOfGuarantee".
//
//                                        In this example, LetterOfGuarantee is generated in the print manager.
//                                        Processing.PrintForm, and InvoiceOrder is generated in the 
//                                        print manager specified in the PrintManager parameter.
//
//                  - Array - a list of print command IDs.
//
//  * Presentation - String - a command presentation in the Print menu.
//                                         Example: "Proforma invoice".
//
//  * PrintManager - String - (optional) name of the object whose manager module contains the Print 
//                                        procedure that generates spreadsheet documents for this command.
//                                        Default value: name of the object manager module.
//                                         Example: "Document.ProformaInvoice".
//  * PrintObjectsTypes - Array - (optional) list of object types, for which the print command is 
//                                        used. The parameter is used for print commands in document 
//                                        journals, which require checking the passed object type before calling the print manager.
//                                        If a list is blank, whenever the list of print commands is 
//                                        generated in a document journal, it is filled with an 
//                                        object type, from which the print command was imported.
//
//  * Handler - String - (optional) client command handler executed instead of the standard print 
//                                        command handler. It is used, for example, when the print 
//                                        form is generated on the client.
//                                        Format "<CommonModuleName>.<ProcedureName>" is used when 
//                                        the procedure is in a common module.
//                                        The <ProcedureName> format is used when the procedure is 
//                                        placed in the main form module of a report or data processor specified in PrintManager.
//                                        Example:
//                                          PrintCommand.Handler = "_DemoStandardSubsystemsClient.PrintProformaInvoices";
//                                        An example of handler in the form module:
//                                          // Generates a print form <print form presentation>.
//                                          //
//                                          // Parameters:
//                                          // PrintParameters - Structure - a print form information.
//                                          // * PrintObjects - Array - an array of selected object references.
//                                          // * Form - ClientApplicationForm - a form, from which the print command is called.
//                                          // * AdditionalParameters - Structure - additional print parameters.
//                                          // Other structure keys match the columns of the PrintCommands table,
//                                          // for more information, see the PrintManager.CreatePrintCommandsCollection function.
//                                          //
//                                          &AtClient
//                                          Function <FunctionName> (PrintParameters) Export
//                                          	// Print handler.
//                                          EndFunction
//                                        Remember that the handler is called using the Calculate 
//                                        method, so only a function can act as a handler.
//                                        The return value of the function is not used by the subsystem.
//
//  * Order - Number - (optional) a value from 1 to 100 that indicates the position of the command 
//                                        among other commands. The Print menu commands are sorted 
//                                        by the Order field, then by a presentation.
//                                        The default value is 50.
//
//  * Picture - Picture - (optional) a picture displayed next to the command in the Print menu.
//                                         Example: PictureLib.PDFFormat.
//
//  * FormsList - String - (optional) comma-separated names of forms, in which the command is to be 
//                                        displayed. If the parameter is not specified, the print 
//                                        command is available in all object forms that include the Print subsystem.
//                                         Example: "DocumentForm".
//
//  * Location - String - (optional) name of the form command bar, to which the print command is to 
//                                        be placed. Use this parameter only when the form has more 
//                                        than one Print submenu. In other cases, specify the print 
//                                        command location in the form module upon the method call.
//                                        PrintManager.OnCreateAtServer.
//                                        
//  * FormHeader - String - (optional) an arbitrary string overriding the standard header of the 
//                                        Print documents form.
//                                         Example: "Customize set".
//
//  * FunctionalOptions - String - (optional) comma-separated names of functional options that 
//                                        influence the print command availability.
//
//  * VisibilityConditions - Array - (optional) collection of command visibility conditions 
//                                        depending on the context. The command visibility conditions are specified using the
//                                        AddCommandVisibilityCondition procedure.
//                                        If the parameter is not specified, the command is visible regardless of the context.
//                                        
//  * CheckPostingBeforePrint - Boolean - (optional) shows whether the document posting check is 
//                                        performed before printing. If at least one unposted 
//                                        document is selected, a posting dialog box appears before executing the print command.
//                                        The print command is not executed for unposted documents.
//                                        If the parameter is not specified, the posting check is not performed.
//
//  * SkipPreview - Boolean - (optional) shows whether documents are sent directly to a printer 
//                                        without the print preview. If the parameter is not 
//                                        specified, the print command opens the "Print documents" preview form.
//
//  * SaveFormat - SpreadsheetDocumentFileType - (optional) used for quick saving of a print form 
//                                        (without additional actions) to non-MXL formats.
//                                        If the parameter is not specified, the print form is saved to an MXL format.
//                                         Example: SpreadsheetDocumentFileType.PDF.
//
//                                        In this example, selecting a print command opens a PDF 
//                                        document.
//
//  * OverrideCopiesUserSettings - Boolean - (optional) shows whether the option to save or restore 
//                                        the number of copies selected by user for printing in the 
//                                        PrintDocuments form is to be disabled. If the parameter is 
//                                        not specified, the option of saving or restoring settings will be applied upon opening the form.
//                                        PrintDocuments.
//
//  * SupplementSetWithExternalPrintForms - Boolean - (optional) shows whether the document set is 
//                                        to be supplemented with all external print forms connected 
//                                        to the object (the AdditionalReportsAndDataProcessors subsystem). 
//                                        If the parameter is not specified, external print forms are not added to the set.
//
//  * FixedSet - Boolean - (optional) shows whether users can change the document set.
//                                         If the parameter is not specified, the user can exclude 
//                                        some print forms from the set in the PrintDocuments form 
//                                        and change the number of copies.
//
//  * AdditionalParameters - Structure - (optional) - arbitrary parameters to pass to the print manager.
//
//  * DontWriteToForm - Boolean - (optional) shows whether object writing before the print command 
//                                        execution is disabled. This parameter is used in special circumstances. 
//                                        If the parameter is not specified, the object is written 
//                                        when the object form has a modification flag.
//
//  * FilesExtensionRequired - Boolean - (optional) shows whether attaching of the file extension is 
//                                        required before executing the command. If the parameter is 
//                                        not specified, the file system extension is not attached.
//
// Example:
//
Function CreatePrintCommandsCollection() Export
	
	Result = New ValueTable;
	
	// details
	Result.Columns.Add("ID", New TypeDescription("String"));
	Result.Columns.Add("Presentation", New TypeDescription("String"));
	
	//////////
	// Options (optional parameters).
	
	// Print manager
	Result.Columns.Add("PrintManager", Undefined);
	Result.Columns.Add("PrintObjectsTypes", New TypeDescription("Array"));
	
	// Alternative command handler.
	Result.Columns.Add("Handler", New TypeDescription("String"));
	
	// presentation
	Result.Columns.Add("Order", New TypeDescription("Number"));
	Result.Columns.Add("Picture", New TypeDescription("Picture"));
	// Comma-separated names of forms for placing commands.
	Result.Columns.Add("FormsList", New TypeDescription("String"));
	Result.Columns.Add("PlacingLocation", New TypeDescription("String"));
	Result.Columns.Add("FormCaption", New TypeDescription("String"));
	// Comma-separated names of functional options that affect the command visibility.
	Result.Columns.Add("FunctionalOptions", New TypeDescription("String"));
	
	// Dynamic visibility conditions.
	Result.Columns.Add("VisibilityConditions", New TypeDescription("Array"));
	
	// Posting check
	Result.Columns.Add("CheckPostingBeforePrint", New TypeDescription("Boolean"));
	
	// Output
	Result.Columns.Add("SkipPreview", New TypeDescription("Boolean"));
	Result.Columns.Add("SaveFormat"); // SpreadsheetDocumentFileType of set settings
	
	// 
	Result.Columns.Add("OverrideCopiesUserSetting", New TypeDescription("Boolean"));
	Result.Columns.Add("AddExternalPrintFormsToSet", New TypeDescription("Boolean"));
	Result.Columns.Add("FixedSet", New TypeDescription("Boolean")); // restricting set changes additional parameters
	
	// 
	Result.Columns.Add("AdditionalParameters", New TypeDescription("Structure"));
	
	// Special command execution mode. By default, the modified object is written before executing the 
	// command.
	Result.Columns.Add("DontWriteToForm", New TypeDescription("Boolean"));
	
	// For using office document templates in the web client.
	Result.Columns.Add("FileSystemExtensionRequired", New TypeDescription("Boolean"));
	
	// For internal use.
	Result.Columns.Add("HiddenByFunctionalOptions", New TypeDescription("Boolean"));
	Result.Columns.Add("UUID", New TypeDescription("String"));
	Result.Columns.Add("Disabled", New TypeDescription("Boolean"));
	Result.Columns.Add("CommandNameAtForm", New TypeDescription("String"));
	
	Return Result;
	
EndFunction

// Sets visibility conditions of the print command on the form, depending on the context.
//
// Parameters:
//  PrintCommand - ValueTableRow - the PrintCommands collection item in the AddPrintCommands 
//                                           procedure. See description in the CreatePrintCommandsCollection function.
//  Attribute - String - an object attribute name.
//  Value - Arbitrary - an object attribute value.
//  ComparisonMethod - ComparisonType - a value comparison kind. Possible kinds:
//                                           Equal, NotEqual, Greater, GreaterOrEqual, Less, LessOrEqual, InList, and NotInList.
//                                           The default value is Equal.
//
Procedure AddCommandVisibilityCondition(PrintCommand, Attribute, Value, Val ComparisonMethod = Undefined) Export
	If ComparisonMethod = Undefined Then
		ComparisonMethod = ComparisonType.Equal;
	EndIf;
	VisibilityCondition = New Structure;
	VisibilityCondition.Insert("Attribute", Attribute);
	VisibilityCondition.Insert("ComparisonType", ComparisonMethod);
	VisibilityCondition.Insert("Value", Value);
	PrintCommand.VisibilityConditions.Add(VisibilityCondition);
EndProcedure

// It is used when transferring a template (metadata object) of a print form to another object.
// It is intended to be called in the procedure for filling in the update data (for the deferred handler).
// Registers a new address of a template to process.
//
// Parameters:
//  TemplateName - String - a new name of the template in the format of
//                         "Document.<DocumentName>.<TemplateName>"
//                         "DataProcessor.<DataProcessorName>.<TemplateName>"
//                         "CommonTemplate.<TemplateName>":
//  Parameters - Structure - see InfobaseUpdate.MainProcessingMarkParameters. 
//
Procedure RegisterNewTemplateName(TemplateName, Parameters) Export
	TemplateNameParts = TemplateNameParts(TemplateName);
	
	RecordSet = InformationRegisters.UserPrintTemplates.CreateRecordSet();
	RecordSet.Filter.TemplateName.Set(TemplateNameParts.TemplateName);
	RecordSet.Filter.Object.Set(TemplateNameParts.ObjectName);
	
	InfobaseUpdate.MarkForProcessing(Parameters, RecordSet);
EndProcedure

// It is used when transferring a template (metadata object) of a print form to another object.
// It is intended to be called in the deferred update handler.
// Transfers user data related to the template to a new address.
//
// Parameters:
//  Templates - Map - information about previous and new template names in the format of
//                              "Document.<DocumentName>.<TemplateName>"
//                              "DataProcessor.<DataProcessorName>.<TemplateName>"
//                              "CommonTemplate.<TemplateName>":
//   * Key - String - a new template name.
//   * Value - String - a previous template name.
//
//  Parameters - Structure - parameters passed to the deferred update handler.
//
Procedure TransferUserTemplates(Templates, Parameters) Export
	
	DataForProcessing = InfobaseUpdate.SelectStandaloneInformationRegisterDimensionsToProcess(Parameters.PositionInQueue, "InformationRegister.UserPrintTemplates");
	While DataForProcessing.Next() Do
		NewTemplateName = DataForProcessing.Object + "." + DataForProcessing.TemplateName;
		PreviousTemplateName = Templates[NewTemplateName];
		TemplateNameParts = TemplateNameParts(PreviousTemplateName);
		
		RecordManager = InformationRegisters.UserPrintTemplates.CreateRecordManager();
		RecordManager.TemplateName = TemplateNameParts.TemplateName;
		RecordManager.Object = TemplateNameParts.ObjectName;
		RecordManager.Read();
		
		If RecordManager.Selected() Then
			RecordSet = InformationRegisters.UserPrintTemplates.CreateRecordSet();
			RecordSet.Filter.TemplateName.Set(DataForProcessing.TemplateName);
			RecordSet.Filter.Object.Set(DataForProcessing.Object);
			Record = RecordSet.Add();
			Record.TemplateName = DataForProcessing.TemplateName;
			Record.Object = DataForProcessing.Object;
			FillPropertyValues(Record, RecordManager, , "TemplateName,Object");
			InfobaseUpdate.WriteData(RecordSet);
			RecordManager.Delete();
		EndIf;
	EndDo;
	Parameters.ProcessingCompleted = InfobaseUpdate.DataProcessingCompleted(Parameters.PositionInQueue, "InformationRegister.UserPrintTemplates");
	
EndProcedure

// Provides an additional access profile "Edit, send by email, save print forms to file (additional)".
// For use in the OnFillSuppliedAccessGroupsProfiles procedure of the AccessManagementOverridable module.
//
// Parameters:
//  ProfilesDetails - Array - see AccessManagementOverridable.OnFillSuppliedAccessGroupsProfiles. 
//
Procedure FillProfileEditPrintForms(ProfilesDetails) Export
	
	ModuleAccessManagement = Common.CommonModule("AccessManagement");
	ProfileDetails = ModuleAccessManagement.NewAccessGroupProfileDescription();;
	ProfileDetails.ID = "70179f20-2315-11e6-9bff-d850e648b60c";
	ProfileDetails.Description = NStr("ru = 'Редактирование, отправка по почте, сохранение в файл печатных форм (дополнительно)'; en = 'Edit, send by email, save print forms to file (additionally)'; pl = 'Edycja, wysyłanie na e-mail, zapisywanie do pliku formularzy wydruku (opcjonalnie)';es_ES = 'Edición, envío por correo, guarda en el archivo de los formularios de impresión (adicional)';es_CO = 'Edición, envío por correo, guarda en el archivo de los formularios de impresión (adicional)';tr = 'Düzenleme, posta ile gönderme, basılı form dosyasına kaydetme (ek olarak)';it = 'Modifica, invia tramite email, salva moduli di stampa per file (aggiunta)';de = 'Bearbeitung, Versand per Post, Speichern von gedruckten Formularen in einer Datei (optional)'",
		Metadata.DefaultLanguage.LanguageCode);
	ProfileDetails.Details = NStr("ru = 'Дополнительно назначается пользователям, которым должна быть доступна возможность редактирования,
		|перед печатью, отправка по почте и сохранение в файл сформированных печатных форм.'; 
		|en = 'Additionally assigned to those users who can edit
		|before printing, send by email, and save to file of generated print forms.'; 
		|pl = 'Dodatkowo przypisuje się użytkownikom, którym powinna być dostępna możliwość edycji,
		|przed wydrukowaniem, wysyłanie pocztą i zapisywanie do pliku uformowanych formularzy wydruku.';
		|es_ES = 'Se establece adicionalmente para los usuarios a los que debe estar disponible la posibilidad de editar 
		|antes de imprimir, el envío por correo y guardar en el archivo los formularios de impresión generados.';
		|es_CO = 'Se establece adicionalmente para los usuarios a los que debe estar disponible la posibilidad de editar 
		|antes de imprimir, el envío por correo y guardar en el archivo los formularios de impresión generados.';
		|tr = 'Ayrıca, 
		|yazdırmadan önce düzenleme, posta ile gönderme ve oluşturulan yazdırılan formların bir dosyasına kaydetme seçeneği olan kullanıcılara atanır.';
		|it = 'Aggiuntivamente assegnato a quegli utenti che possono
		|modificare la stampa, inviare via e-mail e salvare nel file i moduli di stampa generati.';
		|de = 'Zusätzlich wird es den Benutzern zugewiesen, die berechtigt sind, die Formulare
		|vor dem Drucken zu bearbeiten, sie per E-Mail zu versenden und in einer Datei der generierten Druckformularen zu speichern.'", Metadata.DefaultLanguage.LanguageCode);
	ProfileDetails.Roles.Add("PrintFormsEdit");
	ProfilesDetails.Add(ProfileDetails);
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Operations with office document templates.

// Adds a new area record to the TemplateAreas parameter.
//
// Parameters:
//   OfficeDocumentTemplateAreas - Array - a set of areas (array of structures) of an office document template.
//   AreaName - String - name of the area being added.
//   AreaType - String - an area type:
//			Header
//			Footer
//			Total
//			TableRow
//			List
//
// Example:
//	Function OfficeDocumentTemplateAreas()
//	
//		Areas = New Structure
//	
//		PrintManager.AddAreaDetails(Areas, "Header",	"Header")
//		PrintManager.AddAreaDetails(Areas, "Footer",	"Footer")
//		PrintManager.AddAreaDetails(Areas, "Title",			"Total")
//	
//		Area Return.
//	
//	EndFunction
//
Procedure AddAreaDetails(OfficeDocumentTemplateAreas, Val AreaName, Val AreaType) Export
	
	NewArea = New Structure;
	
	NewArea.Insert("AreaName", AreaName);
	NewArea.Insert("AreaType", AreaType);
	
	OfficeDocumentTemplateAreas.Insert(AreaName, NewArea);
	
EndProcedure

// Gets all data required for printing within a single call: object template data, binary template 
// data, and template area description.
// Used for calling print forms based on office document templates from client modules.
//
// Parameters:
//   PrintManagerName - String - a name for accessing the object manager, for example, Document.<Document name>.
//   TemplatesNames - String - names of templates used for print form generation.
//   DocumentsContent - Array - references to infobase objects (all references must be of the same type).
//
// Returns:
//  Map - a collection of references to objects and their data:
//   * Key - AnyRef - reference to an infobase object.
//   * Value - Structure - a template and data:
//       ** Key - String - a template name.
//       ** Value - Structure - object data.
//
Function TemplatesAndObjectsDataToPrint(Val PrintManagerName, Val TemplatesNames, Val DocumentsContent) Export
	
	TemplatesNamesArray = StrSplit(TemplatesNames, ", ", False);
	
	ObjectManager = Common.ObjectManagerByFullName(PrintManagerName);
	TemplatesAndData = ObjectManager.GetPrintInfo(DocumentsContent, TemplatesNamesArray);
	TemplatesAndData.Insert("LocalPrintFileFolder", Undefined); // For backward compatibility.
	
	If NOT TemplatesAndData.Templates.Property("TemplateTypes") Then
		TemplatesAndData.Templates.Insert("TemplateTypes", New Map); // For backward compatibility.
	EndIf;
	
	Return TemplatesAndData;
	
EndFunction

// Returns a print form template by the full path to the template.
//
// Parameters:
//  PathToTemplate - String - a full path to the template in the following format:
//                         "Document.<DocumentName>.<TemplateName>"
//                         "DataProcessor.<DataProcessorName>.<TemplateName>"
//                         "CommonTemplate.<TemplateName>".
//  LanguageCode - String - code of the language in which you want to get the template.
//
// Returns:
//  SpreadsheetDocument - for a template of the MXL type.
//  BinaryData - for office document templates.
//
Function PrintFormTemplate(PathToTemplate, Val LanguageCode = Undefined) Export
	
	Template = FindTemplate(PathToTemplate);
	If TypeOf(Template) = Type("SpreadsheetDocument") Then
		
		If LanguageCode = Undefined Then
			LanguageCode = NationalLanguageSupportClientServer.DefaultLanguageCode();
		EndIf;
			
		Template.LanguageCode = LanguageCode;
		
	EndIf;
	
	Return Template;
	
EndFunction

// Switches the use of a user template to a configuration template.
//
// Parameters:
//  PathToTemplate - String - a full path to the template in the following format:
//                         "Document.<DocumentName>.<TemplateName>"
//                         "DataProcessor.<DataProcessorName>.<TemplateName>"
//                         "CommonTemplate.<TemplateName>".
//
Procedure DisableUserTemplate(PathToTemplate) Export
	
	StringParts = StrSplit(PathToTemplate, ".", True);
	If StringParts.Count() <> 2 AND StringParts.Count() <> 3 Then
		Raise StringFunctionsClientServer.SubstituteParametersToString(NStr("ru = 'Макет ""%1"" не найден.'; en = 'Template %1 is not found.'; pl = 'Makieta ""%1"" nie została znaleziona.';es_ES = 'Modelo ""%1"" no se ha encontrado.';es_CO = 'Modelo ""%1"" no se ha encontrado.';tr = '""%1"" şablonu bulunamadı.';it = 'Il template %1 non è stato trovato.';de = 'Layout ""%1"" wurde nicht gefunden.'"), PathToTemplate);
	EndIf;
	
	TemplateName = StringParts[StringParts.UBound()];
	StringParts.Delete(StringParts.UBound());
	OwnerName = StrConcat(StringParts, ".");
	
	
	RecordSet = InformationRegisters.UserPrintTemplates.CreateRecordSet();
	RecordSet.Filter.Object.Set(OwnerName);
	RecordSet.Filter.TemplateName.Set(TemplateName);
	RecordSet.Read();
	For Each Record In RecordSet Do
		Record.Use = False;
	EndDo;
	
	If RecordSet.Count() > 0 Then
		If InfobaseUpdate.IsCallFromUpdateHandler() Then
			InfobaseUpdate.WriteRecordSet(RecordSet);
		Else
			SetSafeModeDisabled(True);
			SetPrivilegedMode(True);
			
			RecordSet.Write();
			
			SetPrivilegedMode(False);
			SetSafeModeDisabled(False);
		EndIf;
	EndIf;
	
EndProcedure

// Returns a spreadsheet document by binary data of a spreadsheet document.
//
// Parameters:
//  BinaryDocumentData - BinaryData - binary data of a spreadsheet document.
//
// Returns:
//  SpreadsheetDocument - a spreadsheet document.
//
Function SpreadsheetDocumentByBinaryData(BinaryDocumentData) Export
	
	TempFileName = GetTempFileName();
	BinaryDocumentData.Write(TempFileName);
	SpreadsheetDocument = New SpreadsheetDocument;
	SpreadsheetDocument.Read(TempFileName);
	
	SafeModeSet = SafeMode();
	If TypeOf(SafeModeSet) = Type("String") Then
		SafeModeSet = True;
	EndIf;
	
	If Not SafeModeSet Then
		DeleteFiles(TempFileName);
	EndIf;
	
	Return SpreadsheetDocument;
	
EndFunction

// Returns binary data for generating a QR code.
//
// Parameters:
//  QRString - String - data to be placed in the QR code.
//
//  CorrectionLevel - Number - an image defect level, at which it is still possible to completely recognize this QR
//                             code.
//                     The parameter must have an integer type and have one of the following possible values:
//                     0 (7% defect allowed), 1 (15% defect allowed), 2 (25% defect allowed), 3 (35% defect allowed).
//
//  Size - Number - determines the size of the output image side, in pixels.
//                     If the smallest possible image size is greater than this parameter, the code is not generated.
//
// Returns:
//  BinaryData - a buffer that contains the bytes of the QR code image in PNG format.
// 
// Example:
//  
//  // Printing a QR code containing information encrypted according to UFEBM.
//
//  QRString = PrintManager.UFEBMFormatString(PaymentDetails)
//  ErrorText = ""
//  QRCodeData = AccessManagement.QRCodeData(QRString, 0, 190, ErrorText)
//  If Not BlankString (ErrorText)
//      CommonClientServer.MessageToUser(ErrorText)
//  EndIf
//
//  QRCodePicture = New Picture(QRCodeData)
//  TemplateArea.Pictures.QRCode.Picture = QRCodePicture
//
Function QRCodeData(QRString, CorrectionLevel, Size) Export
	
	SetSafeModeDisabled(True);
	QRCodeGenerator = QRCodeGenerationComponent();
	If QRCodeGenerator = Undefined Then
		Return Undefined;
	EndIf;
	
	Try
		BinaryPictureData = QRCodeGenerator.GenerateQRCode(QRString, CorrectionLevel, Size);
	Except
		WriteLogEvent(NStr("ru = 'Формирование QR-кода'; en = 'Generating QR code'; pl = 'Generacja kodu QR';es_ES = 'Generación del código QR';es_CO = 'Generación del código QR';tr = 'QR kodu oluşturulması';it = 'Generazione del QR code';de = 'QR-Code-Generierung'", CommonClientServer.DefaultLanguageCode()),
			EventLogLevel.Error, , , DetailErrorDescription(ErrorInfo()));
	EndTry;
	
	Return BinaryPictureData;
	
EndFunction

// Generates a format string according to "Unified formats for electronic banking messages" for its 
// display as a QR code.
//
// Parameters:
//  DocumentData - Structure - contains document field values.
//    The document data will be encoded according to the standard
//    "STANDARDS FOR FINANCIAL TRANSACTIONS. Two-dimensional barcode characters for making payments of individuals".
//    DocumentData must contain information in the fields described below.
//    Required fields of the structure:
//     * PayeeText - a payee description, up to 160 characters.
//     * PayeeAccount - a payee account number - up to 20 characters.
//     * PayeeBankName - a payee bank payee description, up to 45 characters.
//     * PayeeBankBIC          - BIC                                     - up to nine characters.
//     * PayeeBankAccount -  a payee bank account number - up to 20 characters.
//    Additional fields of the following structure:
//     * AmountAsNumber - a payment amount in rubles, up to 16 characters.
//     * PaymentPurpose - a payment payee description (purpose), up to 210 characters.
//     * PayeeTIN - a payee TIN - up to 12 characters.
//     * PayerTIN - a payer TIN - up to 12 characters.
//     * AuthorStatus - a status of a payment document author - up to 2 characters.
//     * PayeeCRTR - a payee CRTR - up to 9 characters.
//     * BCCode - BCC - up to 20 characters.
//     * RNCMTCode - RNCMT code - up to 11 characters.
//     * BaseIndicator - a tax payment reason - up to 2 characters.
//     * PeriodIndicator - a fiscal period - up to 10 characters.
//     * NumberIndicator - a document number - up to 15 characters.
//     * DateIndicator - a document date - up to 10 characters.
//     * TypeIndicator - a payment type - up to 2 characters.
//    Other additional fields.
//     * LastPayerName - a payer's last name.
//     * PayerName - a payer name.
//     * PayerPatronymic - a payer's middle name.
//     * PayerAddress - a payer address.
//     * BudgetPayeeAccount - a budget payee account.
//     * PaymentDocumentIndex - a payment document index.
//     * IIAN - a PF individual account number (IIAN).
//     * ContractNumber - a contract number.
//     * PayerAccount - a payer account number in the company (in the personal accounting system).
//     * ApartmentNumber - an apartment number.
//     * PhoneNumber - a phone number.
//     * PayerKind - a payer identity document kind.
//     * PayerNumber - a payer identity document number.
//     * FullChildName - a full name of a student or a child.
//     * BirthDate - a date of birth.
//     * PaymentTerm - a payment term or a proforma invoice date.
//     * PayPeriod - a payment period.
//     * PaymentKind - a payment kind.
//     * ServiceCode - a service code or a metering device name.
//     * MeterNumber - a metering device number.
//     * MeterValue - a metering device value.
//     * NotificationNumber - a notification, accrual, or proforma invoice number.
//     * NotificationDate - date of notification, accrual, proforma invoice, or order (for State Traffic Safety Inspectorate).
//     * InstitutionNumber - an institution (educational, healthcare) number.
//     * GroupNumber - a number of kindergarten group or school grade.
//     * FullTeacherName - a full name of the teacher or the specialist who provides the service.
//     * InsuranceAmount - an amount of insurance, additional services, or late payment charge (in kopecks).
//     * Order - an order ID (for State Traffic Safety Inspectorate).
//     * EnforcementOrderNumber - an enforcement order number.
//     * PaymentKindCode - a payment kind code (for example, for payments to Federal Agency for State Registration).
//     * AccrualID - an accrual UUID.
//     * TechnicalCode - a technical code recommended to be filled by a service provider.
//                                          It can be used by a host company to call the appropriate 
//                                          processing IT system.
//                                          The code value list is presented below.
//
//       Purpose code - a payment purpose.
//       
//       
//          01 Mobile communications, fixed line telephone.
//          02 Utility services, housing and public utilities.
//          03 State Traffic Safety Inspectorate, taxes, duties, budgetary payments.
//          04 Security services
//          05 Services provided by FMS.
//          06 PF
//          07 Loan repayments
//          08 Educational institutions.
//          09 Internet and TV
//          10 Electronic money
//          11 Recreation and travel.
//          12 Investment and insurance.
//          13 Sports and health
//          14 Charitable and public organizations.
//          15 Other services.
//
// Returns:
//   String - data string in the UFEBM format.
//
Function UFEBMFormatString(DocumentData) Export
	
	ErrorText = "";
	RequiredAttributesString = RequiredAttributesString(DocumentData, ErrorText);
	
	If IsBlankString(RequiredAttributesString) Then
		CommonClientServer.MessageToUser(ErrorText, , , ,);
		Return "";
	EndIf;
	
	PresentationsAndAttributesStructure = PresentationsAndAttributesStructure();
	AdditionalAttributesString = "";
	AdditionalAttributes = New Structure;
	AddAdditionalAttributes(AdditionalAttributes);
	
	For Each Item In AdditionalAttributes Do
		
		If Not DocumentData.Property(Item.Key) Then
			DocumentData.Insert(Item.Key, "");
			Continue;
		EndIf;
		
		If ValueIsFilled(DocumentData[Item.Key]) Then
			If Item.Key = "AmountAsNumber" Then
				ValueAsString = Format(DocumentData.AmountAsNumber * 100, "NG=");
			Else
				ValueAsString = StrReplace(TrimAll(String(DocumentData[Item.Key])), "|", "");
			EndIf;
			AdditionalAttributesString = AdditionalAttributesString + PresentationsAndAttributesStructure[Item.Key]
			                                 + "=" + ValueAsString + "|";
		EndIf;
	EndDo;
	
	If Not IsBlankString(AdditionalAttributesString) Then
		StringLength = StrLen(AdditionalAttributesString);
		AdditionalAttributesString = Mid(AdditionalAttributesString, 1, StringLength - 1);
	EndIf;

	OtherAdditionalAttributes = New Structure;
	AddOtherAdditionalAttributes(OtherAdditionalAttributes);
	OtherAdditionalAttributesString = "";
	
	For Each Item In OtherAdditionalAttributes Do
		
		If Not DocumentData.Property(Item.Key) Then
			DocumentData.Insert(Item.Key, "");
			Continue;
		EndIf;
		
		If ValueIsFilled(DocumentData[Item.Key]) Then
			ValueAsString = StrReplace(TrimAll(String(DocumentData[Item.Key])), "|", "");
			OtherAdditionalAttributesString = OtherAdditionalAttributesString
			                                       + PresentationsAndAttributesStructure[Item.Key] + "=" + ValueAsString
			                                       + "|";
		EndIf;
	EndDo;
	
	If Not IsBlankString(OtherAdditionalAttributesString) Then
		StringLength = StrLen(OtherAdditionalAttributesString);
		OtherAdditionalAttributesString = Mid(OtherAdditionalAttributesString, 1, StringLength - 1);
	EndIf;
	
	TotalString = RequiredAttributesString
	                 + ?(IsBlankString(AdditionalAttributesString), "", "|" + AdditionalAttributesString)
	                 + ?(IsBlankString(OtherAdditionalAttributesString), "", "|" + OtherAdditionalAttributesString);
	
	Return TotalString;
	
EndFunction

// Generates print forms in the required format and writes them to files.
// Restriction: print forms generated on the client are not supported.
//
// Parameters:
//  PrintCommands  - Structure, Array - a command or several form print commands. See PrintManager.
//                                       FormPrintCommands. 
//  ObjectsList - Array    - references to the objects to print.
//  SettingsForSaving - Structure - see PrintManager.SettingsForSaving. 
//
// Returns:
//  ValueTable - print form files:
//   * FileName - String - a file name.
//   * BinaryData - BinaryData - a print form file.
//
Function PrintToFile(PrintCommands, ObjectsList, SettingsForSaving) Export
	
	Result = New ValueTable;
	Result.Columns.Add("FileName");
	Result.Columns.Add("BinaryData");
	
	CommandsList = PrintCommands;
	If TypeOf(PrintCommands) <> Type("Array") Then
		CommandsList = CommonClientServer.ValueInArray(PrintCommands);
	EndIf;
	
	For Each PrintCommand In CommandsList Do
		MessageTemplatesDrive.SetPrintOptions(PrintCommand, ObjectsList);
		ExecutePrintToFileCommand(PrintCommand, SettingsForSaving, ObjectsList, Result);
	EndDo;
	
	If SettingsForSaving.PackToArchive Then
		BinaryData = PackToArchive(Result);
		Result.Clear();
		File = Result.Add();
		File.FileName = FileName(GetTempFileName("zip"));
		File.BinaryData = BinaryData;
	EndIf;
	
	Return Result;
	
EndFunction

// Constructor of the SettingsForSaving parameter of the PrintManager.PrintToFile function.
// Defines a format and other settings of writing a spreadsheet document to file.
// 
// Returns:
//  Structure - settings of writing a spreadsheet document to file.
//   * SaveFormats - Array - a collection of values of the SpreadsheetDocumentFileType type or 
//                                  values of the SpreadsheetDocumentFileType type converted into a string.
//   * PackToArchive   - Boolean - if set to True, one archive file with files of the specified formats will be created.
//   * TransliterateFilesNames - Boolean - if set to True, names of the received files will be in Latin characters.
//   * SignatureAndSeal    - Boolean - if it is set to True and a spreadsheet document being saved 
//                                  supports placement of signatures and seals, they will be placed to saved files.
//
Function SettingsForSaving() Export
	
	Return PrintManagementClientServer.SettingsForSaving();
	
EndFunction

#Region OperationsWithOfficeDocumentsTemplates

////////////////////////////////////////////////////////////////////////////////
// Operations with office document templates.

//	The section contains interface functions (API) used for creating print forms based on office 
//	documents. Currently, office suites that work with the Office Open XML format (Microsoft Office, 
//	Open Office, Google Docs) are supported.
//
////////////////////////////////////////////////////////////////////////////////
//	Used data types (determined by specific implementations).
//	RefPrintForm	- a reference to a print form.
//	RefTemplate			- a reference to a template.
//	Area				- a reference to a print form area or a template area (structure), it is overridden with 
//						internal area data in the interface module.
//						
//	AreaDetails		- a template area description (see below).
//	FillingData	- either a structure or an array of structures (for lists and tables.
//						
////////////////////////////////////////////////////////////////////////////////
//	AreaDetails - a structure that describes template areas prepared by the user key AreaName - an 
//	area name key AreaTypeType - 	Header.
//	
//							Footer
//							FirstHeader
//							FirstFooter
//							EvenHeader
//							EvenFooter
//							Total
//							TableRow
//							List
//

////////////////////////////////////////////////////////////////////////////////
// Functions for initializing and closing references.

// Creates a structure of the output print form.
// Call this function before performing any actions on the form.
//
// Parameters:
//  DeleteDocumentType - String - an obsolete parameter, not used.
//  DeleteTemplatePageSettings - Map - an obsolete parameter, not used.
//  Template - Structure - see PrintManager.InitializeTemplate. 
//
// Returns:
//  Structure - a new print form.
//
Function InitializePrintForm(Val DeleteDocumentType, Val DeleteTemplatePageSettings = Undefined, Template = Undefined) Export
	
	If Template = Undefined Then
		Raise "ru = 'Required specify value parameter ""Template""'";
	EndIf;
	
	PrintForm = PrintManagementInternal.InitializePrintForm(Template);
	PrintForm.Insert("Type", "DOCX");
	PrintForm.Insert("LastOutputArea", Undefined);
	
	Return PrintForm;
	
EndFunction

// Creates a template structure. This structure is used later for receiving template areas (tags and 
// tables), headers, and footers.
//
// Parameters:
//  BinaryTemplateData - BinaryData - a binary template data.
//  DeleteTemplateType - String - an obsolete parameter, not used.
//  DeleteTemplateName - String - an obsolete parameter, not used.
//
// Returns:
//  Structure - a template.
//
Function InitializeOfficeDocumentTemplate(BinaryTemplateData, Val DeleteTemplateType, Val DeleteTemplateName = "") Export
	
	Template = PrintManagementInternal.GetTemplate(BinaryTemplateData);
	If Template <> Undefined Then
		Template.Insert("Type", "DOCX");
		Template.Insert("TemplatePagesSettings", New Map);
	EndIf;
	
	Return Template;
	
EndFunction

// Deletes temporary files formed after expanding an xml template structure.
// Call it every time after generation of a template and a print form, as well as in the event of 
// generation termination.
//
// Parameters:
//  PrintForm - Structure - see PrintManager.InitializePrintForm. 
//  DeleteCloseApplication - Boolean - an obsolete parameter, not used.
//
Procedure ClearRefs(PrintForm, Val DeleteCloseApplication = True) Export
	
	If PrintForm <> Undefined Then
		PrintManagementInternal.CloseConnection(PrintForm);
		PrintForm = Undefined;
	EndIf;
	
EndProcedure

// Generates a file of an output print form and places it in the storage.
// Call this method after adding all areas to a print form structure.
//
// Parameters:
//  PrintForm - Structure - see PrintManager.InitializePrintForm. 
//
// Returns:
//  String - a storage address, to which the generated file is placed.
//
Function GenerateDocument(Val PrintForm) Export
	
	PrintFormStorageAddress = PrintManagementInternal.GenerateDocument(PrintForm);
	
	Return PrintFormStorageAddress;
	
EndFunction

////////////////////////////////////////////////////////////////////////////////
// Functions for getting template areas, outputting template areas to print forms, and filling 
// parameters in template areas.

// Gets a print form template area.
//
// Parameters:
//   RefToTemplate - Structure - a print form template.
//   AreaDetails - Structure - an area description.
//
// Returns:
//  Structure - a template area.
//
Function TemplateArea(RefToTemplate, AreaDetails) Export
	
	Area = Undefined;
	
	If AreaDetails.AreaType = "Header" OR AreaDetails.AreaType = "EvenHeader" OR AreaDetails.AreaType = "FirstHeader" Then
		Area = PrintManagementInternal.GetHeaderArea(RefToTemplate, AreaDetails.AreaName);
	ElsIf AreaDetails.AreaType = "Footer"  OR AreaDetails.AreaType = "EvenFooter"  OR AreaDetails.AreaType = "FirstFooter" Then
		Area = PrintManagementInternal.GetFooterArea(RefToTemplate, AreaDetails.AreaName);
	ElsIf AreaDetails.AreaType = "Total" Then
		Area = PrintManagementInternal.GetTemplateArea(RefToTemplate, AreaDetails.AreaName);
	ElsIf AreaDetails.AreaType = "TableRow" Then
		Area = PrintManagementInternal.GetTemplateArea(RefToTemplate, AreaDetails.AreaName);
	ElsIf AreaDetails.AreaType = "List" Then
		Area = PrintManagementInternal.GetTemplateArea(RefToTemplate, AreaDetails.AreaName);
	Else
		Raise StringFunctionsClientServer.SubstituteParametersToString(NStr("ru = 'Тип области не указан или указан некорректно: %1.'; en = 'Area type is not specified or specified incorrectly: %1.'; pl = 'Nie określono typu obszaru, lub określono go niepopranie: %1.';es_ES = 'Tipo de área no está especificado o especificado de forma incorrecta: %1.';es_CO = 'Tipo de área no está especificado o especificado de forma incorrecta: %1.';tr = 'Alan tipi yanlış belirtilmemiş veya belirtilmemiş: %1.';it = 'Il tipo di area non è specificato o specificato in modo errato: %1.';de = 'Bereichstyp ist nicht angegeben oder falsch angegeben: %1.'"), AreaDetails.AreaType);
	EndIf;
	
	If Area <> Undefined Then
		Area.Insert("AreaDetails", AreaDetails);
	EndIf;
	
	Return Area;
	
EndFunction

// Attaches an area to a template print form.
// The procedure is used upon output of a single area.
//
// Parameters:
//  PrintForm - Structure - a print form, see PrintManager.InitializePrintForm. 
//  TemplateArea - Structure - see PrintManager.TemplateArea. 
//  GoToNextRow - Boolean - True, if you need to add a line break after the area output.
//
Procedure AttachArea(PrintForm, TemplateArea, Val GoToNextRow = False) Export
	
	If TemplateArea = Undefined Then
		Return;
	EndIf;
	
	Try
		
		AreaDetails = TemplateArea.AreaDetails;
	
		OutputArea = Undefined;
		
		If AreaDetails.AreaType = "Header" OR AreaDetails.AreaType = "EvenHeader" OR AreaDetails.AreaType = "FirstHeader" Then
				OutputArea = PrintManagementInternal.AddHeader(PrintForm, TemplateArea);
		ElsIf AreaDetails.AreaType = "Footer"  OR AreaDetails.AreaType = "EvenFooter"  OR AreaDetails.AreaType = "FirstFooter" Then
			OutputArea = PrintManagementInternal.AddFooter(PrintForm, TemplateArea);
		ElsIf AreaDetails.AreaType = "Total" Then
			OutputArea = PrintManagementInternal.AttachArea(PrintForm, TemplateArea, GoToNextRow);
		ElsIf AreaDetails.AreaType = "List" OR AreaDetails.AreaType = "TableRow" Then
			OutputArea = PrintManagementInternal.AttachArea(PrintForm, TemplateArea, GoToNextRow);
		Else
			Raise AreaTypeSpecifiedIncorrectlyText();
		EndIf;
		
		AreaDetails.Insert("Area", OutputArea);
		AreaDetails.Insert("GoToNextRow", GoToNextRow);
		
		// Contains an area type and area borders (if required).
		PrintForm.LastOutputArea = AreaDetails;
		
	Except
		ErrorMessage = TrimAll(BriefErrorDescription(ErrorInfo()));
		ErrorMessage = ?(Right(ErrorMessage, 1) = ".", ErrorMessage, ErrorMessage + ".");
		ErrorMessage = ErrorMessage + " " + StringFunctionsClientServer.SubstituteParametersToString(NStr("ru = 'Ошибка при попытке вывести область ""%1"" из макета.'; en = 'An error occurred when outputting the ""%1"" template area.'; pl = 'Podczas próby uzyskania obszaru ""%1"" z szablonu wystąpił błąd.';es_ES = 'Ha ocurrido un error al intentar obtener el área ""%1"" desde el modelo.';es_CO = 'Ha ocurrido un error al intentar obtener el área ""%1"" desde el modelo.';tr = 'Şablondan alan ""%1"" elde etmeye çalışırken bir hata oluştu.';it = 'Un errore si è registrato durante l''emissione della area template ""%1"".';de = 'Beim Versuch, den Bereich ""%1"" aus der Vorlage zu erhalten, ist ein Fehler aufgetreten.'"),
			TemplateArea.AreaDetails.AreaName);
		Raise ErrorMessage;
	EndTry;
	
EndProcedure

// Fills parameters of the print form area.
//
// Parameters:
//  PrintForm - Structure - either a print form area or a print form itself.
//  Data - Structure - filling data.
//
Procedure FillParameters(PrintForm, Data) Export
	
	AreaDetails = PrintForm.LastOutputArea;
	
	If AreaDetails.AreaType = "Header" OR AreaDetails.AreaType = "EvenHeader" OR AreaDetails.AreaType = "FirstHeader" Then
		PrintManagementInternal.FillHeaderParameters(PrintForm, PrintForm.LastOutputArea.Area, Data);
	ElsIf AreaDetails.AreaType = "Footer"  OR AreaDetails.AreaType = "EvenFooter"  OR AreaDetails.AreaType = "FirstFooter" Then
		PrintManagementInternal.FillFooterParameters(PrintForm, PrintForm.LastOutputArea.Area, Data);
	ElsIf AreaDetails.AreaType = "Total"
			OR AreaDetails.AreaType = "TableRow"
			OR AreaDetails.AreaType = "List" Then
		PrintManagementInternal.FillParameters(PrintForm, PrintForm.LastOutputArea.Area, Data);
	Else
		Raise AreaTypeSpecifiedIncorrectlyText();
	EndIf;

EndProcedure

// Adds an area from a template to a print form, replacing the area parameters with the object data values.
// The procedure is used upon output of a single area.
//
// Parameters:
//  PrintForm - Structure - a print form, see PrintManager.InitializePrintForm. 
//  TemplateArea - Structure - see PrintManager.TemplateArea. 
//  Data - Structure - filling data.
//  GoToNextRow - Boolean - True, if you need to add a line break after the area output.
//
Procedure AttachAreaAndFillParameters(PrintForm, TemplateArea, Data, Val GoToNextRow = False) Export
	
	If TemplateArea = Undefined Then
		Return;
	EndIf;
	
	AttachArea(PrintForm, TemplateArea, GoToNextRow);
	FillParameters(PrintForm, Data);
	
EndProcedure

// Adds an area from a template to a print form, replacing the area parameters with the object data 
// values.
// The procedure is used upon output of a single area.
//
// Parameters:
//  PrintForm - Structure - a print form, see PrintManager.InitializePrintForm. 
//  TemplateArea - Structure - see PrintManager.TemplateArea. 
//  Data - Array - an item collection of the Structure type, object data.
//  GoToNextRow - Boolean - True, if you need to add a line break after the area output.
//
Procedure JoinAndFillCollection(PrintForm, TemplateArea, Data, Val GoToNextRow = False) Export
	
	If TemplateArea = Undefined Then
		Return;
	EndIf;
	
	AreaDetails = TemplateArea.AreaDetails;
	
	If AreaDetails.AreaType = "TableRow" OR AreaDetails.AreaType = "List" Then
		PrintManagementInternal.JoinAndFillSet(PrintForm, TemplateArea, Data, GoToNextRow);
	Else
		Raise AreaTypeSpecifiedIncorrectlyText();
	EndIf;
	
EndProcedure

// Inserts a line break as a newline character.
//
// Parameters:
//  PrintForm - Structure - a print form, see PrintManager.InitializePrintForm. 
//
Procedure InsertBreakAtNewLine(PrintForm) Export
	
	PrintManagementInternal.InsertBreakAtNewLine(PrintForm);
	
EndProcedure

#EndRegion

#Region ObsoleteProceduresAndFunctions

// Obsolete. Use AttachableCommands.OnCreateAtServer.
// Places print commands in a form.
//
// Parameters:
//   Form - ClientApplicationForm - a form, where the Print submenu is to be placed.
//   DefaultCommandsLocation - FormItem - a group for placing the Print submenu, the default 
//                                                     location is the form command bar.
//   PrintObjects - Array - a list of metadata objects, for which it is required to generate a joint 
//                                               Print submenu.
Procedure OnCreateAtServer(Form, DefaultCommandsLocation = Undefined, PrintObjects = Undefined) Export
	PlacementParameters = AttachableCommands.PlacementParameters();
	If TypeOf(DefaultCommandsLocation) = Type("FormGroup") Then
		If DefaultCommandsLocation.Type = FormGroupType.Popup
			Or DefaultCommandsLocation.Title = NStr("ru = 'Печать'; en = 'Print'; pl = 'Drukuj';es_ES = 'Impresión';es_CO = 'Impresión';tr = 'Yazdır';it = 'Stampa';de = 'Drucken'")
			Or DefaultCommandsLocation.Name = "PrintSubmenu" Then
			Parent = DefaultCommandsLocation.Parent;
			If TypeOf(Parent) = Type("FormGroup") Then
				PlacementParameters.CommandBar = Parent;
			EndIf;
		Else
			PlacementParameters.CommandBar = DefaultCommandsLocation;
		EndIf;
	EndIf;
	If TypeOf(PrintObjects) = Type("Array") Then
		PlacementParameters.Sources = PrintObjects;
	EndIf;
	AttachableCommands.OnCreateAtServer(Form, PlacementParameters);
EndProcedure

// Obsolete. The LocalPrintFilesDirectory setting is out of use.
// Returns a path to the directory used for printing.
//
// Returns:
//  String - a full path to the temporary directory of print files.
//
Function GetLocalDirectoryOfPrintFiles() Export
	Return "";
EndFunction

#EndRegion

#EndRegion

#Region Internal

// Hides print commands from the Print submenu.
Procedure DisablePrintCommands(ObjectsList, CommandsList) Export
	RecordSet = InformationRegisters.PrintCommandsSettings.CreateRecordSet();
	For Each Object In ObjectsList Do
		ObjectPrintCommands = StandardObjectPrintCommands(Object);
		For Each IDOfCommandToReplace In CommandsList Do
			Filter = New Structure;
			Filter.Insert("ID", IDOfCommandToReplace);
			Filter.Insert("SaveFormat");
			Filter.Insert("SkipPreview", False);
			Filter.Insert("Disabled", False);
			
			ListOfCommandsToReplace = ObjectPrintCommands.FindRows(Filter);
			For Each CommandToReplace In ListOfCommandsToReplace Do
				RecordSet.Filter.Owner.Set(Object);
				RecordSet.Filter.UUID.Set(CommandToReplace.UUID);
				RecordSet.Read();
				RecordSet.Clear();
				If RecordSet.Count() = 0 Then
					Record = RecordSet.Add();
				Else
					Record = RecordSet[0];
				EndIf;
				Record.Owner = Object;
				Record.UUID = CommandToReplace.UUID;
				Record.Visible = False;
				RecordSet.Write();
			EndDo;
		EndDo;
	EndDo;
EndProcedure

// Returns a list of supplied object printing commands.
//
// Parameters:
//  Object - CatalogRef.MetadataObjectsIDs
Function StandardObjectPrintCommands(Object) Export
	ObjectPrintCommands = ObjectPrintCommands(
		Common.MetadataObjectByID(Object));
		
	ExternalPrintCommands = ObjectPrintCommands.FindRows(New Structure("PrintManager", "StandardSubsystems.AdditionalReportsAndDataProcessors"));
	For Each PrintCommand In ExternalPrintCommands Do
		ObjectPrintCommands.Delete(PrintCommand);
	EndDo;
	
	Return ObjectPrintCommands;
EndFunction

// Returns a list of metadata objects, in which the Print subsystem is embedded.
//
// Returns:
//  Array - a list of items of the MetadataObject type.
Function PrintCommandsSources() Export
	ObjectsWithPrintCommands = New Array;
	
	ObjectsList = New Array;
	SSLSubsystemsIntegration.OnDefineObjectsWithPrintCommands(ObjectsWithPrintCommands);
	CommonClientServer.SupplementArray(ObjectsWithPrintCommands, ObjectsList, True);
	
	ObjectsList = New Array;
	PrintManagementOverridable.OnDefineObjectsWithPrintCommands(ObjectsList);
	CommonClientServer.SupplementArray(ObjectsWithPrintCommands, ObjectsList, True);
	
	Result = New Array;
	For Each ObjectManager In ObjectsWithPrintCommands Do
		Result.Add(Metadata.FindByType(TypeOf(ObjectManager)));
	EndDo;
	
	Return Result;
EndFunction

// Constructor for the PrintFormsCollection of the Print procedure.
//
// Returns:
//  ValueTable - a blank collection of print forms:
//   * TemplateName - String - a print form ID.
//   * NameUpper - String - an ID in uppercase for quick search.
//   * Synonym - String - a print form presentation.
//   * SpreadsheetDocument - SpreadsheetDocument - a print form.
//   * Copies - Number - a number of copies to be printed.
//   * Picture - Picture - (not used).
//   * FullPathToTemplate - String - used for quick access to print form template editing.
//   * PrintFormFileName - String - a file name.
//                           - Map - file names for each object:
//                              ** Key - AnyRef - a reference to the print object.
//                              ** Value - String - a file name.
//   * OfficeDocuments - Map - a collection of print forms in the format of office documents:
//                         ** Key - String - an address in the temporary storage of binary data of the print form.
//                         ** Value - String - a print form file name.
Function PreparePrintFormsCollection(Val TemplatesNames) Export
	
	Templates = New ValueTable;
	Templates.Columns.Add("TemplateName");
	Templates.Columns.Add("UpperCaseName");
	Templates.Columns.Add("TemplateSynonym");
	Templates.Columns.Add("SpreadsheetDocument");
	Templates.Columns.Add("Copies");
	Templates.Columns.Add("Picture");
	Templates.Columns.Add("FullPathToTemplate");
	Templates.Columns.Add("PrintFormFileName");
	Templates.Columns.Add("OfficeDocuments");
	
	If TypeOf(TemplatesNames) = Type("String") Then
		TemplatesNames = StrSplit(TemplatesNames, ",");
	EndIf;
	
	For Each TemplateName In TemplatesNames Do
		Template = Templates.Find(TemplateName, "TemplateName");
		If Template = Undefined Then
			Template = Templates.Add();
			Template.TemplateName = TemplateName;
			Template.UpperCaseName = Upper(TemplateName);
			Template.Copies = 1;
		Else
			Template.Copies = Template.Copies + 1;
		EndIf;
	EndDo;
	
	Return Templates;
	
EndFunction

// Preparing a structure of output parameters for the object manager that generates print forms.
//
Function PrepareOutputParametersStructure() Export
	
	OutputParameters = New Structure;
	OutputParameters.Insert("PrintBySetsAvailable", False); // not used
	
	EmailParametersStructure = New Structure("Recipient,Subject,Text", Undefined, "", "");
	OutputParameters.Insert("SendOptions", EmailParametersStructure);
	
	Return OutputParameters;
	
EndFunction

Function PrintSettings() Export
	
	Settings = New Structure;
	Settings.Insert("UseSignaturesAndSeals", True);
	Settings.Insert("HideSignaturesAndSealsForEditing", False);
	
	PrintManagementOverridable.OnDefinePrintSettings(Settings);
	
	Return Settings;
	
EndFunction

////////////////////////////////////////////////////////////////////////////////
// Message templates.

// Prepares print forms for message templates
//
Function PreparePrintForms(Val PrintManagerName, Val TemplatesNames, Val ObjectsArray, Val PrintParameters, 
	AllowedPrintObjectsTypes = Undefined) Export
	Return GeneratePrintForms(PrintManagerName, TemplatesNames, ObjectsArray, PrintParameters, AllowedPrintObjectsTypes);
EndFunction

// Returns allowed for saving print form formats for message templates.
//
Function SpreadsheetDocumentSaveFormats() Export
	Return SpreadsheetDocumentSaveFormatsSettings();
EndFunction

Function ObjectPrintCommandsAvailableForAttachments(MetadataObject) Export
	Return ObjectPrintCommands(MetadataObject);
EndFunction

// Generates a print form based on an external source.
//
// Parameters:
//   AdditionalDataProcessorRef - CatalogRef.AdditionalReportsAndDataProcessors - an external data processor.
//   SourceParameters            - Structure - a structure with the following properties:
//       * CommandID - String - a list of comma-separated templates.
//       * RelatedObjects    - Array
//   PrintFormsCollection - ValueTable - see the Print() procedure description available in the documentation.
//   PrintObjects - ValueList - see the Print() procedure description available in the documentation.
//   OutputParameters - Structure - see the Print() procedure description available in the documentation.
//
Procedure PrintByExternalSource(AdditionalDataProcessorRef, SourceParameters, PrintFormsCollection,
	PrintObjects, OutputParameters) Export
	
	ModuleAdditionalReportsAndDataProcessors = Common.CommonModule("AdditionalReportsAndDataProcessors");
	ExternalDataProcessorObject = ModuleAdditionalReportsAndDataProcessors.ExternalDataProcessorObject(AdditionalDataProcessorRef);
	If ExternalDataProcessorObject = Undefined Then
		Raise StringFunctionsClientServer.SubstituteParametersToString(
			NStr("ru = 'Внешняя обработка ""%1"" (тип ""%2"") не обслуживается.'; en = 'The ""%1"" external data processor (the ""%2"" type) is not supported.'; pl = 'Zewnętrzna obróbka ""%1"" (rodzaj ""%2"") nie jest obsługiwana.';es_ES = 'Procesamiento externo ""%1"" (tipo ""%2"") no se soporta.';es_CO = 'Procesamiento externo ""%1"" (tipo ""%2"") no se soporta.';tr = '""%1"" harici veri işlemcisi (""%2"" türü) desteklenmiyor.';it = 'L''elaboratore di dati esterno ""%1"" (di tipo ""%2"") non è supportato.';de = 'Externe Verarbeitung ""%1"" (Typ ""%2"") wird nicht bearbeitet.'"),
			String(AdditionalDataProcessorRef),
			String(TypeOf(AdditionalDataProcessorRef)));
	EndIf;
	
	PrintFormsCollection = PreparePrintFormsCollection(SourceParameters.CommandID);
	OutputParameters = PrepareOutputParametersStructure();
	OutputParameters.Insert("AdditionalDataProcessorRef", AdditionalDataProcessorRef);
	
	ExternalDataProcessorObject.Print(
		SourceParameters.RelatedObjects,
		PrintFormsCollection,
		PrintObjects,
		OutputParameters);
	
	// Checking if all templates are generated.
	For Each PrintForm In PrintFormsCollection Do
		If PrintForm.SpreadsheetDocument = Undefined Then
			ErrorMessageText = StringFunctionsClientServer.SubstituteParametersToString(
				NStr("ru = 'В обработчике печати не был сформирован табличный документ для: %1'; en = 'Spreadsheet document is not generated in the print handler for: %1'; pl = 'Dokument tabelaryczny nie został wygenerowany w procesorze wydruku: %1';es_ES = 'Documento de la hoja de cálculo para %1 no se ha generado en el procesador de impresión';es_CO = 'Documento de la hoja de cálculo para %1 no se ha generado en el procesador de impresión';tr = '%1 için elektronik tablo belgesi yazdırma işlemcisinde oluşturulmadı';it = 'Il documento di foglio di calcolo non viene generato nel gestore di stampa per: %1';de = 'Das Tabellenkalkulationsdokument für %1 wurde nicht im Druckhandler generiert'"),
				PrintForm.TemplateName);
			Raise(ErrorMessageText);
		EndIf;
		
		PrintForm.SpreadsheetDocument.Copies = PrintForm.Copies;
	EndDo;
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Configuration subsystems event handlers.

// See AttachableCommandsOverridable.OnDefineAttachableObjectsSettingsComposition. 
Procedure OnDefineAttachableObjectsSettingsComposition(InterfaceSettings) Export
	Setting = InterfaceSettings.Add();
	Setting.Key          = "AddPrintCommands";
	Setting.TypeDescription = New TypeDescription("Boolean");
EndProcedure

// See AttachableCommandsOverridable.OnDefineAttachableCommandsKinds. 
Procedure OnDefineAttachableCommandsKinds(AttachableCommandsKinds) Export
	Kind = AttachableCommandsKinds.Add();
	Kind.Name         = "Print";
	Kind.SubmenuName  = "PrintSubmenu";
	Kind.Title   = NStr("ru = 'Печать'; en = 'Print'; pl = 'Drukuj';es_ES = 'Impresión';es_CO = 'Impresión';tr = 'Yazdır';it = 'Stampa';de = 'Drucken'");
	Kind.Order     = 40;
	Kind.Picture    = PictureLib.Print;
	Kind.Representation = ButtonRepresentation.PictureAndText;
EndProcedure

// See AttachableCommandsOverridable.OnDefineCommandsAttachedToObject. 
Procedure OnDefineCommandsAttachedToObject(FormSettings, Sources, AttachedReportsAndDataProcessors, Commands) Export
	
	ObjectsList = New Array;
	For Each Source In Sources.Rows Do
		ObjectsList.Add(Source.Metadata);
	EndDo;
	If Sources.Rows.Count() = 1 AND Common.IsDocumentJournal(Sources.Rows[0].Metadata) Then
		ObjectsList = Undefined;
	EndIf;
	
	PrintCommands = FormPrintCommands(FormSettings.FormName, ObjectsList);
	
	HandlerParametersKeys = "Handler, PrintManager, FormCaption, SkipPreview, SaveFormat,
	|OverrideCopiesUserSetting, AddExternalPrintFormsToSet,
	|FixedSet, AdditionalParameters";
	For Each PrintCommand In PrintCommands Do
		If PrintCommand.Disabled Then
			Continue;
		EndIf;
		Command = Commands.Add();
		FillPropertyValues(Command, PrintCommand, , "Handler");
		Command.Kind = "Print";
		Command.Popup = PrintCommand.PlacingLocation;
		Command.MultipleChoice = True;
		If PrintCommand.PrintObjectsTypes.Count() > 0 Then
			Command.ParameterType = New TypeDescription(PrintCommand.PrintObjectsTypes);
		EndIf;
		Command.VisibilityInForms = PrintCommand.FormsList;
		If PrintCommand.DontWriteToForm Then
			Command.WriteMode = "DoNotWrite";
		ElsIf PrintCommand.CheckPostingBeforePrint Then
			Command.WriteMode = "Post";
		Else
			Command.WriteMode = "Write";
		EndIf;
		Command.FilesOperationsRequired = PrintCommand.FileSystemExtensionRequired;
		
		Command.Handler = "PrintManagementInternalClient.CommandHandler";
		Command.AdditionalParameters = New Structure(HandlerParametersKeys);
		FillPropertyValues(Command.AdditionalParameters, PrintCommand);
	EndDo;
	
EndProcedure

// See UsersOverridable.OnDefineRolesAssignment. 
Procedure OnDefineRoleAssignment(RolesAssignment) Export
	
	// ForSystemUsersOnly.
	RolesAssignment.BothForUsersAndExternalUsers.Add(
		Metadata.Roles.PrintFormsEdit.Name);
	
EndProcedure

// See InfobaseUpdateSSL.OnAddUpdateHandlers. 
Procedure OnAddUpdateHandlers(Handlers) Export
	
	Handler = Handlers.Add();
	Handler.Version = "2.1.2.5";
	Handler.Procedure = "PrintManagement.ResetUserSettingsPrintDocumentsForm";
	
	Handler = Handlers.Add();
	Handler.Version = "2.1.3.22";
	Handler.Procedure = "PrintManagement.ConvertUserMXLTemplateBinaryDataToSpreadsheetDocuments";
	
	Handler = Handlers.Add();
	Handler.Version = "2.4.1.1";
	Handler.Procedure = "PrintManagement.AddEditPrintFormsRoleToBasicRightsProfiles";
	Handler.ExecutionMode = "Seamless";
	
	Handler = Handlers.Add();
	Handler.Version = "3.0.1.60";
	Handler.Procedure = "InformationRegisters.UserPrintTemplates.ProcessUserTemplates";
	Handler.ExecutionMode = "Deferred";
	Handler.DeferredProcessingQueue = 1;
	Handler.Comment = NStr("ru = 'Очищает пользовательские макеты, в которых нет изменений по сравнению с соответствующими поставляемыми макетами.
		|Отключает пользовательские макеты, которые не совместимы с текущей версией конфигурации.'; 
		|en = 'Clears user templates that have no changes compared to the corresponding supplied templates.
		|Disables user templates that are incompatible with the current configuration version.'; 
		|pl = 'Oczyszcza niestandardowe makiety, w których nie ma zmian w porównaniu z odpowiednimi dostarczanymi makietami.
		|Wyłącza makiety użytkowników, które nie są kompatybilne z aktualną wersją konfiguracji.';
		|es_ES = 'Limpia los modelos de usuario en los que no hay cambios comparando con los modelos suministrados correspondientes.
		|Desactiva los modelos de usuario que no son compatibles con la versión actual de la configuración.';
		|es_CO = 'Limpia los modelos de usuario en los que no hay cambios comparando con los modelos suministrados correspondientes.
		|Desactiva los modelos de usuario que no son compatibles con la versión actual de la configuración.';
		|tr = 'Verilen düzenlere göre değişiklik yapılmayan kullanıcı şablonları temizler. 
		|Geçerli yapılandırma sürümü ile uyumlu olmayan kullanıcı şablonları devre dışı bırakır.';
		|it = 'Cancella modelli utente che non sono stati modificati rispetto ai modelli corrispondenti forniti.
		|Disabilita modelli utente incompatibili con la versione di configurazione corrente.';
		|de = 'Löscht benutzerdefinierte Layouts, die im Vergleich zu den entsprechenden ausgelieferten Layouts keine Änderungen aufweisen.
		|Deaktiviert benutzerdefinierte Layouts, die nicht mit der aktuellen Version der Konfiguration kompatibel sind.'");
	Handler.ID = New UUID("e5b0d876-c766-40a0-a0cf-ffccc83a193f");
	Handler.CheckProcedure = "InfobaseUpdate.DataUpdatedForNewApplicationVersion";
	Handler.ObjectsToLock = "InformationRegister.UserPrintTemplates";
	Handler.UpdateDataFillingProcedure = "InformationRegisters.UserPrintTemplates.RegisterDataToProcessForMigrationToNewVersion";
	Handler.ObjectsToRead = "InformationRegister.UserPrintTemplates";
	Handler.ObjectsToChange = "InformationRegister.UserPrintTemplates";
	
EndProcedure

// See SafeModeManagerOverridable.OnFillPermissionsToAccessExternalResources. 
Procedure OnFillPermissionsToAccessExternalResources(PermissionRequests) Export
	
	ModuleSafeModeManager = Common.CommonModule("SafeModeManager");
	
	Permissions = New Array;
	Permissions.Add(ModuleSafeModeManager.PermissionToUseAddIn(
		"CommonTemplate.QRCodePrintingComponent", NStr("ru = 'Печать QR кодов.'; en = 'Print QR codes.'; pl = 'Drukowanie kodów QR.';es_ES = 'Imprimir los códigos QR.';es_CO = 'Imprimir los códigos QR.';tr = 'QR kodlarını yazdır.';it = 'Stampa QR code.';de = 'QR-Codes drucken'")));
	PermissionRequests.Add(
		ModuleSafeModeManager.RequestToUseExternalResources(Permissions));
	
EndProcedure

// See ToDoListOverridable.OnDetermineToDoListHandlers. 
Procedure OnFillToDoList(ToDoList) Export
	
	ModuleToDoListServer = Common.CommonModule("ToDoListServer");
	If Not AccessRight("Edit", Metadata.InformationRegisters.UserPrintTemplates)
		Or ModuleToDoListServer.UserTaskDisabled("PrintFormTemplates") Then
		Return;
	EndIf;
	
	// If there is no Administration section, a to-do is not added.
	Subsystem = Metadata.Subsystems.Find("Administration");
	If Subsystem = Undefined
		Or Not AccessRight("View", Subsystem)
		Or Not Common.MetadataObjectAvailableByFunctionalOptions(Subsystem) Then
		Sections = ModuleToDoListServer.SectionsForObject("InformationRegister.UserPrintTemplates");
	Else
		Sections = New Array;
		Sections.Add(Subsystem);
	EndIf;
	
	OutputUserTask = True;
	VersionChecked = CommonSettingsStorage.Load("ToDoList", "PrintForms");
	If VersionChecked <> Undefined Then
		ArrayVersion  = StrSplit(Metadata.Version, ".");
		CurrentVersion = ArrayVersion[0] + ArrayVersion[1] + ArrayVersion[2];
		If VersionChecked = CurrentVersion Then
			OutputUserTask = False; // Current version print forms are checked.
		EndIf;
	EndIf;
	
	UserTemplatesCount = CountOfUsedUserTemplates();
	
	For Each Section In Sections Do
		SectionID = "CheckCompatibilityWithCurrentVersion" + StrReplace(Section.FullName(), ".", "");
		
		// Adding a to-do.
		UserTask = ToDoList.Add();
		UserTask.ID = "PrintFormTemplates";
		UserTask.HasUserTasks      = OutputUserTask AND UserTemplatesCount > 0;
		UserTask.Presentation = NStr("ru = 'Макеты печатных форм'; en = 'Print form templates'; pl = 'Szablony formularza wydruku';es_ES = 'Versión impresa modelos';es_CO = 'Versión impresa modelos';tr = 'Yazdırma formu şablonları';it = 'Layout moduli di stampa';de = 'Formularvorlagen drucken'");
		UserTask.Count    = UserTemplatesCount;
		UserTask.Form         = "InformationRegister.UserPrintTemplates.Form.CheckPrintForms";
		UserTask.Owner      = SectionID;
		
		// Checking whether the to-do group exists. If a group is missing, add it.
		UserTaskGroup = ToDoList.Find(SectionID, "ID");
		If UserTaskGroup = Undefined Then
			UserTaskGroup = ToDoList.Add();
			UserTaskGroup.ID = SectionID;
			UserTaskGroup.HasUserTasks      = UserTask.HasUserTasks;
			UserTaskGroup.Presentation = NStr("ru = 'Проверить совместимость'; en = 'Check compatibility'; pl = 'Kontrola zgodności';es_ES = 'Revisar la compatibilidad';es_CO = 'Revisar la compatibilidad';tr = 'Uygunluğu kontrol et';it = 'Verificare la compatibilità';de = 'Überprüfen Sie die Kompatibilität'");
			If UserTask.HasUserTasks Then
				UserTaskGroup.Count = UserTask.Count;
			EndIf;
			UserTaskGroup.Owner = Section;
		Else
			If Not UserTaskGroup.HasUserTasks Then
				UserTaskGroup.HasUserTasks = UserTask.HasUserTasks;
			EndIf;
			
			If UserTask.HasUserTasks Then
				UserTaskGroup.Count = UserTaskGroup.Count + UserTask.Count;
			EndIf;
		EndIf;
	EndDo;
	
EndProcedure

#EndRegion

#Region Private

// Resets user print form settings: number of copies and order.
Procedure ResetUserSettingsPrintDocumentsForm() Export
	Common.CommonSettingsStorageDelete("PrintFormsSettings", Undefined, Undefined);
EndProcedure

// Converts user MXL templates stored as binary data to spreadsheet documents.
Procedure ConvertUserMXLTemplateBinaryDataToSpreadsheetDocuments() Export
	
	QueryText = 
	"SELECT
	|	UserPrintTemplates.TemplateName,
	|	UserPrintTemplates.Object,
	|	UserPrintTemplates.Template,
	|	UserPrintTemplates.Use
	|FROM
	|	InformationRegister.UserPrintTemplates AS UserPrintTemplates";
	
	Query = New Query(QueryText);
	TemplatesSelection = Query.Execute().Select();
	
	While TemplatesSelection.Next() Do
		If StrStartsWith(TemplatesSelection.TemplateName, "PF_MXL") Then
			TempFileName = GetTempFileName();
			
			BinaryTemplateData = TemplatesSelection.Template.Get();
			If TypeOf(BinaryTemplateData) <> Type("BinaryData") Then
				Continue;
			EndIf;
			
			BinaryTemplateData.Write(TempFileName);
			
			SpreadsheetDocumentRead = True;
			SpreadsheetDocument = New SpreadsheetDocument;
			Try
				SpreadsheetDocument.Read(TempFileName);
			Except
				SpreadsheetDocumentRead = False; // This file is not a spreadsheet document. Deleting the file.
			EndTry;
			
			Record = InformationRegisters.UserPrintTemplates.CreateRecordManager();
			FillPropertyValues(Record, TemplatesSelection, , "Template");
			
			If SpreadsheetDocumentRead Then
				Record.Template = New ValueStorage(SpreadsheetDocument, New Deflation(9));
				Record.Write();
			Else
				Record.Delete();
			EndIf;
		EndIf;
	EndDo;
	
EndProcedure

// Adds the PrintFormsEditing role to all profiles that have the BasicSSLRights role.
Procedure AddEditPrintFormsRoleToBasicRightsProfiles() Export
	
	If Not Common.SubsystemExists("StandardSubsystems.AccessManagement") Then
		Return;
	EndIf;
	
	ModuleAccessManagement = Common.CommonModule("AccessManagement");
	
	NewRoles = New Array;
	NewRoles.Add(Metadata.Roles.BasicSSLRights.Name);
	NewRoles.Add(Metadata.Roles.PrintFormsEdit.Name);
	
	RolesToReplace = New Map;
	RolesToReplace.Insert(Metadata.Roles.BasicSSLRights.Name, NewRoles);
	
	ModuleAccessManagement.ReplaceRolesInProfiles(RolesToReplace);
	
EndProcedure

// Returns a reference to the source object of the external print form.
//
// Parameters:
//  ID - String - a form ID.
//  FullMetadataObjectName - String - a full name of the metadata object for getting a reference to 
//                                        the external print form source.
//
// Returns:
//  Ref.
Function AdditionalPrintFormRef(ID, FullMetadataObjectName)
	ExternalPrintFormRef = Undefined;
	
	If Common.SubsystemExists("StandardSubsystems.AdditionalReportsAndDataProcessors") Then
		ModuleAdditionalReportsAndDataProcessors = Common.CommonModule("AdditionalReportsAndDataProcessors");
		ModuleAdditionalReportsAndDataProcessors.OnReceiveExternalPrintForm(ID, FullMetadataObjectName, ExternalPrintFormRef);
	EndIf;
	
	Return ExternalPrintFormRef;
EndFunction

// Generating print forms.
Function GeneratePrintForms(Val PrintManagerName, Val TemplatesNames, Val ObjectsArray, Val PrintParameters, 
	AllowedPrintObjectsTypes = Undefined) Export
	
	PrintFormsCollection = PreparePrintFormsCollection(New Array);
	PrintObjects = New ValueList;
	OutputParameters = PrepareOutputParametersStructure();
	
	If TypeOf(TemplatesNames) = Type("String") Then
		TemplatesNames = StrSplit(TemplatesNames, ",");
	Else // Type("Array")
		TemplatesNames = CommonClientServer.CopyArray(TemplatesNames);
	EndIf;
	
	ExternalPrintFormsPrefix = "ExternalPrintForm.";
	
	ExternalPrintFormsSource = PrintManagerName;
	If Common.IsReference(TypeOf(ObjectsArray)) Then
		ExternalPrintFormsSource = ObjectsArray.Metadata().FullName();
	Else
		If ObjectsArray.Count() > 0 Then
			ExternalPrintFormsSource = ObjectsArray[0].Metadata().FullName();
		EndIf;
	EndIf;
	ExternalPrintForms = PrintFormsListFromExternalSources(ExternalPrintFormsSource);
	
	// Adding external print forms to a set.
	AddedExternalPrintForms = New Array;
	If TypeOf(PrintParameters) = Type("Structure") 
		AND PrintParameters.Property("AddExternalPrintFormsToSet") 
		AND PrintParameters.AddExternalPrintFormsToSet Then 
		
		ExternalPrintFormsIDs = ExternalPrintForms.UnloadValues();
		For Each ID In ExternalPrintFormsIDs Do
			TemplatesNames.Add(ExternalPrintFormsPrefix + ID);
			AddedExternalPrintForms.Add(ExternalPrintFormsPrefix + ID);
		EndDo;
	EndIf;
	
	For Each TemplateName In TemplatesNames Do
		// Checking for a printed form.
		FoundPrintForm = PrintFormsCollection.Find(TemplateName, "TemplateName");
		If FoundPrintForm <> Undefined Then
			LastAddedPrintForm = PrintFormsCollection[PrintFormsCollection.Count() - 1];
			If LastAddedPrintForm.TemplateName = FoundPrintForm.TemplateName Then
				LastAddedPrintForm.Copies = LastAddedPrintForm.Copies + 1;
			Else
				PrintFormCopy = PrintFormsCollection.Add();
				FillPropertyValues(PrintFormCopy, FoundPrintForm);
				PrintFormCopy.Copies = 1;
			EndIf;
			Continue;
		EndIf;
		
		// Checking whether an additional print manager is specified in the print form name.
		AdditionalPrintManagerName = "";
		ID = TemplateName;
		ExternalPrintForm = Undefined;
		If StrFind(ID, ExternalPrintFormsPrefix) > 0 Then // This is an external print form
			ID = Mid(ID, StrLen(ExternalPrintFormsPrefix) + 1);
			ExternalPrintForm = ExternalPrintForms.FindByValue(ID);
		ElsIf StrFind(ID, ".") > 0 Then // Additional print manager is specified.
			Position = StrFind(ID, ".", SearchDirection.FromEnd);
			AdditionalPrintManagerName = Left(ID, Position - 1);
			ID = Mid(ID, Position + 1);
		EndIf;
		
		// Determining an internal print manager.
		UsedPrintManager = AdditionalPrintManagerName;
		If IsBlankString(UsedPrintManager) Then
			UsedPrintManager = PrintManagerName;
		EndIf;
		
		// Checking whether the objects being printed match the selected print form.
		ObjectTypeToExpect = Undefined;
		
		ObjectsCorrespondingToPrintForm = ObjectsArray;
		If AllowedPrintObjectsTypes <> Undefined AND AllowedPrintObjectsTypes.Count() > 0 Then
			If TypeOf(ObjectsArray) = Type("Array") Then
				ObjectsCorrespondingToPrintForm = New Array;
				For Each Object In ObjectsArray Do
					If AllowedPrintObjectsTypes.Find(TypeOf(Object)) = Undefined Then
						MessagePrintFormUnavailable(Object);
					Else
						ObjectsCorrespondingToPrintForm.Add(Object);
					EndIf;
				EndDo;
				If ObjectsCorrespondingToPrintForm.Count() = 0 Then
					ObjectsCorrespondingToPrintForm = Undefined;
				EndIf;
			ElsIf Common.RefTypeValue(ObjectsArray) Then // The passed variable is not an array
				If AllowedPrintObjectsTypes.Find(TypeOf(ObjectsArray)) = Undefined Then
					MessagePrintFormUnavailable(ObjectsArray);
					ObjectsCorrespondingToPrintForm = Undefined;
				EndIf;
			EndIf;
		EndIf;
		
		TempCollectionForSinglePrintForm = PreparePrintFormsCollection(ID);
		
		// Calling the Print procedure from the print manager.
		If ExternalPrintForm <> Undefined Then
			// Print manager in an external print form.
			PrintByExternalSource(
				AdditionalPrintFormRef(ExternalPrintForm.Value, ExternalPrintFormsSource),
				New Structure("CommandID, RelatedObjects", ExternalPrintForm.Value, ObjectsCorrespondingToPrintForm),
				TempCollectionForSinglePrintForm,
				PrintObjects,
				OutputParameters);
		Else
			If Not IsBlankString(UsedPrintManager) Then
				PrintManager = Common.ObjectManagerByFullName(UsedPrintManager);
				// Printing an internal print form.
				If ObjectsCorrespondingToPrintForm <> Undefined Then
					PrintManager.Print(ObjectsCorrespondingToPrintForm, PrintParameters, TempCollectionForSinglePrintForm, 
						PrintObjects, OutputParameters);
				Else
					TempCollectionForSinglePrintForm[0].SpreadsheetDocument = New SpreadsheetDocument;
				EndIf;
			EndIf;
		EndIf;
		
		// Checking filling of the print form collection received from a print manager.
		For Each PrintFormDetails In TempCollectionForSinglePrintForm Do
			CommonClientServer.Validate(
				TypeOf(PrintFormDetails.Copies) = Type("Number") AND PrintFormDetails.Copies > 0,
				StringFunctionsClientServer.SubstituteParametersToString(NStr("ru = 'Не задано количество экземпляров для печатной формы ""%1"".'; en = 'The number of copies is not specified for %1 print form.'; pl = 'Nie określono ilości kopii dla formularza wydruku ""%1"".';es_ES = 'Número de copias no está especificado para la versión impresa ""%1"".';es_CO = 'Número de copias no está especificado para la versión impresa ""%1"".';tr = '%1 yazdırma formu için kopya sayısı belirtilmedi.';it = 'Il numero di copie non è specificato per il modulo di stampa %1.';de = 'Die Anzahl der Kopien ist nicht für das Druckformular ""%1"" angegeben.'"),
				?(IsBlankString(PrintFormDetails.TemplateSynonym), PrintFormDetails.TemplateName, PrintFormDetails.TemplateSynonym)));
		EndDo;
				
		// Updating the collection
		Cancel = TempCollectionForSinglePrintForm.Count() = 0;
		// A single print form is required but the entire collection is processed for backward compatibility.
		For Each TempPrintForm In TempCollectionForSinglePrintForm Do 
			
			If NOT TempPrintForm.OfficeDocuments = Undefined Then
				TempPrintForm.SpreadsheetDocument = New SpreadsheetDocument;
			EndIf;
			
			If TempPrintForm.SpreadsheetDocument <> Undefined Then
				PrintForm = PrintFormsCollection.Add();
				FillPropertyValues(PrintForm, TempPrintForm);
				If TempCollectionForSinglePrintForm.Count() = 1 Then
					PrintForm.TemplateName = TemplateName;
					PrintForm.UpperCaseName = Upper(TemplateName);
				EndIf;
			Else
				// An error occurred when generating a print form.
				Cancel = True;
			EndIf;
			
		EndDo;
		
		// Raising an exception based on the error.
		If Cancel Then
			ErrorMessageText = StringFunctionsClientServer.SubstituteParametersToString(NStr(
				"ru = 'При формировании печатной формы ""%1"" возникла ошибка. Обратитесь к администратору.'; en = 'An error occurred when generating print form ""%1"". Contact your administrator.'; pl = 'Podczas generowania formularza wydruku ""%1"" wystąpił błąd. Skontaktuj się z administratorem.';es_ES = 'Ha ocurrido un error al generar la versión impresa ""%1"". Contactar su administrador.';es_CO = 'Ha ocurrido un error al generar la versión impresa ""%1"". Contactar su administrador.';tr = '""%1"" yazdırma formu oluşturulurken hata oluştu. Yöneticinize başvurun.';it = 'Si è verificato un errore durante la generazione forma di stampa ""%1"". Contattare l''amministratore.';de = 'Beim Generieren des Druckformulars ""%1"" ist ein Fehler aufgetreten. Kontaktieren Sie Ihren Administrator.'"), TemplateName);
			Raise ErrorMessageText;
		EndIf;
		
	EndDo;
	
	PrintManagementOverridable.OnPrint(ObjectsArray, PrintParameters, PrintFormsCollection, PrintObjects, OutputParameters);
	
	// Setting a number of spreadsheet document copies, checking areas.
	For Each PrintForm In PrintFormsCollection Do
		CheckSpreadsheetDocumentLayoutByPrintObjects(PrintForm.SpreadsheetDocument, 
			PrintObjects, PrintManagerName, PrintForm.TemplateName);
		If AddedExternalPrintForms.Find(PrintForm.TemplateName) <> Undefined Then
			PrintForm.Copies = 0; // For automatically added forms.
		EndIf;
		If PrintForm.SpreadsheetDocument <> Undefined Then
			PrintForm.SpreadsheetDocument.Copies = PrintForm.Copies;
		EndIf;
	EndDo;
	
	Result = New Structure;
	Result.Insert("PrintFormsCollection", PrintFormsCollection);
	Result.Insert("PrintObjects", PrintObjects);
	Result.Insert("OutputParameters", OutputParameters);
	Return Result;
	
EndFunction

// Generates print forms for direct output to a printer.
//
Function GeneratePrintFormsForQuickPrint(PrintManagerName, TemplatesNames, ObjectsArray, PrintParameters) Export
	
	Result = New Structure;
	Result.Insert("SpreadsheetDocuments");
	Result.Insert("PrintObjects");
	Result.Insert("OutputParameters");
	Result.Insert("Cancel", False);
		
	If NOT AccessRight("Output", Metadata) Then
		Result.Cancel = True;
		Return Result;
	EndIf;
	
	PrintForms = GeneratePrintForms(PrintManagerName, TemplatesNames, ObjectsArray, PrintParameters);
		
	SpreadsheetDocuments = New ValueList;
	For Each PrintForm In PrintForms.PrintFormsCollection Do
		If (TypeOf(PrintForm.SpreadsheetDocument) = Type("SpreadsheetDocument")) AND (PrintForm.SpreadsheetDocument.TableHeight <> 0) Then
			SpreadsheetDocuments.Add(PrintForm.SpreadsheetDocument, PrintForm.TemplateSynonym);
		EndIf;
	EndDo;
	
	Result.SpreadsheetDocuments = SpreadsheetDocuments;
	Result.PrintObjects      = PrintForms.PrintObjects;
	Result.OutputParameters    = PrintForms.OutputParameters;
	Return Result;
	
EndFunction

// Generating print forms for direct output to a printer in the server mode in an ordinary 
// application.
//
Function GeneratePrintFormsForQuickPrintOrdinaryApplication(PrintManagerName, TemplatesNames, ObjectsArray, PrintParameters) Export
	
	Result = New Structure;
	Result.Insert("Address");
	Result.Insert("PrintObjects");
	Result.Insert("OutputParameters");
	Result.Insert("Cancel", False);
	
	PrintForms = GeneratePrintFormsForQuickPrint(PrintManagerName, TemplatesNames, ObjectsArray, PrintParameters);
	
	If PrintForms.Cancel Then
		Result.Cancel = PrintForms.Cancel;
		Return Result;
	EndIf;
	
	Result.PrintObjects = New Map;
	
	For Each PrintObject In PrintForms.PrintObjects Do
		Result.PrintObjects.Insert(PrintObject.Presentation, PrintObject.Value);
	EndDo;
	
	Result.Address = PutToTempStorage(PrintForms.SpreadsheetDocuments);
	Return Result;
	
EndFunction

// Returns a table of available formats for saving a spreadsheet document.
//
// Returns
//  ValueTable:
//                   SpreadsheetDocumentFileType - SpreadsheetDocumentFileType - a value in the 
//                                                                                               
//                                                                                               platform that matches the format.
//                   Ref - EnumRef.ReportsSaveFormats - a reference to metadata that stores 
//                                                                                               
//                                                                                               presentation.
//                   Presentation - String - a file type presentation (filled in from enumeration).
//                                                          
//                   Extension - String - a file type for an operating system.
//                                                          
//                   Picture - Picture - a format icon.
//
// Note: the format table can be overridden in the
// PrintManagerOverridable.OnFillSaveFormatsSettings() procedure.
//
Function SpreadsheetDocumentSaveFormatsSettings() Export
	
	FormatsTable = StandardSubsystemsServer.SpreadsheetDocumentSaveFormatsSettings();

	// Adding formats or changing the current ones.
	PrintManagementOverridable.OnFillSpeadsheetDocumentSaveFormatsSettings(FormatsTable);
	
	For Each SaveFormat In FormatsTable Do
		SaveFormat.Presentation = String(SaveFormat.Ref);
	EndDo;
		
	Return FormatsTable;
	
EndFunction

// Filters a list of print commands according to set functional options.
Procedure DefinePrintCommandsVisibilityByFunctionalOptions(PrintCommands, Form = Undefined)
	For CommandNumber = -PrintCommands.Count() + 1 To 0 Do
		PrintCommandDetails = PrintCommands[-CommandNumber];
		FunctionalOptionsOfPrintCommand = StrSplit(PrintCommandDetails.FunctionalOptions, ", ", False);
		CommandVisibility = FunctionalOptionsOfPrintCommand.Count() = 0;
		For Each FunctionalOption In FunctionalOptionsOfPrintCommand Do
			If TypeOf(Form) = Type("ClientApplicationForm") Then
				CommandVisibility = CommandVisibility Or Form.GetFormFunctionalOption(FunctionalOption);
			Else
				CommandVisibility = CommandVisibility Or GetFunctionalOption(FunctionalOption);
			EndIf;
			
			If CommandVisibility Then
				Break;
			EndIf;
		EndDo;
		PrintCommandDetails.HiddenByFunctionalOptions = Not CommandVisibility;
	EndDo;
EndProcedure

// Saves a user print template to the infobase.
Procedure WriteTemplate(TemplateMetadataObjectName, TemplateAddressInTempStorage) Export
	
	ModifiedTemplate = GetFromTempStorage(TemplateAddressInTempStorage);
	
	NameParts = StrSplit(TemplateMetadataObjectName, ".");
	TemplateName = NameParts[NameParts.UBound()];
	
	OwnerName = "";
	For PartNumber = 0 To NameParts.UBound()-1 Do
		If Not IsBlankString(OwnerName) Then
			OwnerName = OwnerName + ".";
		EndIf;
		OwnerName = OwnerName + NameParts[PartNumber];
	EndDo;
	
	If NameParts.Count() = 3 Then
		SetSafeModeDisabled(True);
		SetPrivilegedMode(True);
		
		TemplateFromMetadata = Common.ObjectManagerByFullName(OwnerName).GetTemplate(TemplateName);
		
		SetPrivilegedMode(False);
		SetSafeModeDisabled(False);
	Else
		TemplateFromMetadata = GetCommonTemplate(TemplateName);
	EndIf;
	
	Record = InformationRegisters.UserPrintTemplates.CreateRecordManager();
	Record.Object = OwnerName;
	Record.TemplateName = TemplateName;
	If TemplatesDiffer(TemplateFromMetadata, ModifiedTemplate) Then
		Record.Use = True;
		Record.Template = New ValueStorage(ModifiedTemplate, New Deflation(9));
		Record.Write();
	Else
		Record.Read();
		If Record.Selected() Then
			Record.Delete();
		EndIf;
	EndIf;
	
EndProcedure

Function RequiredAttributesString(DocumentData, MessageText)
	
	RequiredAttributes = New Structure();
	PresentationsAndAttributesStructure = PresentationsAndAttributesStructure();
	AddRequiredAttributes(RequiredAttributes);
	
	If Not ValueIsFilled(DocumentData.RecipientBankAccount) Then
		DocumentData.RecipientBankAccount = "0";
	EndIf;
	
	InternalData = "ST00012";
	RequiredData = "";
	
	For Each Item In RequiredAttributes Do
		If Not ValueIsFilled(DocumentData[Item.Key]) Then
			MessageText = NStr("ru = 'Не заполнен обязательный реквизит: %1'; en = 'The attribute is required: %1'; pl = 'Nie wprowadzono wymaganego atrybutu: %1';es_ES = 'Atributo requerido no se ha introducido: %1';es_CO = 'Atributo requerido no se ha introducido: %1';tr = 'Gerekli özellik girilmemiştir:%1';it = 'L''attributo è richiesto: %1';de = 'Erforderliches Attribut wurde nicht eingegeben: %1'");
			MessageText = StringFunctionsClientServer.SubstituteParametersToString(MessageText, Item.Key);
			Return "";
		EndIf;
		
		ValueAsString = StrReplace(TrimAll(String(DocumentData[Item.Key])), "|", "");
		
		RequiredData = RequiredData + "|" + PresentationsAndAttributesStructure[Item.Key] + "="
		                     + ValueAsString;
		
	EndDo;
	
	If StrLen(RequiredData) > 300 Then
		Template = NStr("ru = 'Невозможно создать QR-код для документа %1
			|Строка обязательных реквизитов должна быть меньше 300 символов:
			|""%2""'; 
			|en = 'Cannot generate QR code for document %1
			|The string of required attributes must be less than 300 characters:
			|""%2""'; 
			|pl = 'Nie można utworzyć kodu QR dla dokumentu %1
			|Wiersz obowiązkowych danych powinien być mniejszy niż 300 znaków:
			|""%2""';
			|es_ES = 'No se puede generar el código QR para el documento %1 
			|Una línea de los atributos requeridos tiene que ser más corta de 300 símbolos:
			|""%2""';
			|es_CO = 'No se puede generar el código QR para el documento %1 
			|Una línea de los atributos requeridos tiene que ser más corta de 300 símbolos:
			|""%2""';
			|tr = '%1 belgesi için QR kod oluşturulamıyor
			|Gerekli özelliklerin dizesi 300 karakterden kısa olmalıdır:
			|""%2""';
			|it = 'Impossibile generare QR code per il documento %1
			|La riga di attributi richiesti deve essere inferiore a 300 caratteri:
			|""%2""';
			|de = 'Es ist nicht möglich, einen QR-Code für ein Dokument zu generieren %1
			|Die Zeichenfolge der obligatorischen Angaben muss weniger als 300 Zeichen lang sein:
			|""%2""'");
		MessageText = StringFunctionsClientServer.SubstituteParametersToString(Template, DocumentData.Ref, RequiredData);
		CommonClientServer.MessageToUser(MessageText);
		Return "";
	EndIf;
	
	Return InternalData + RequiredData;
	
EndFunction

Function PresentationsAndAttributesStructure()
	
	ReturnStructure = New Structure();
	
	ReturnStructure.Insert("RecipientText",             "Name");
	ReturnStructure.Insert("RecipientAccountNumber",        "PersonalAcc");
	ReturnStructure.Insert("RecipientBankDescription", "BankName");
	ReturnStructure.Insert("RecipientBankBIC",          "BIC");
	ReturnStructure.Insert("RecipientBankAccount",         "CorrespAcc");
	
	ReturnStructure.Insert("AmountAsNumber",         "Sum");
	ReturnStructure.Insert("PaymentPurpose",   "Purpose");
	ReturnStructure.Insert("RecipientTIN",       "PayeeINN");
	ReturnStructure.Insert("PayerTIN",      "PayerINN");
	ReturnStructure.Insert("AuthorStatus",   "DrawerStatus");
	ReturnStructure.Insert("RecipientCRTR",       "KPP");
	ReturnStructure.Insert("BCCode",               "CBC");
	ReturnStructure.Insert("RNCMTCode",            "OKTMO");
	ReturnStructure.Insert("BasisIndicator", "PaytReason");
	ReturnStructure.Insert("PeriodIndicator",   "TaxPeriod");
	ReturnStructure.Insert("NumberIndicator",    "DocNo");
	ReturnStructure.Insert("DateIndicator",      "DocDate");
	ReturnStructure.Insert("TypeIndicator",      "TaxPaytKind");
	
	ReturnStructure.Insert("LastPayerName",               "lastName");
	ReturnStructure.Insert("PayerName",                   "firstName");
	ReturnStructure.Insert("PayerPatronymic",              "middleName");
	ReturnStructure.Insert("PayerAddress",                 "payerAddress");
	ReturnStructure.Insert("BudgetPayeeAccount",  "personalAccount");
	ReturnStructure.Insert("PaymentDocumentIndex",        "docIdx");
	ReturnStructure.Insert("IIAN",                            "pensAcc");
	ReturnStructure.Insert("ContractNumber",                    "contract");
	ReturnStructure.Insert("PayerAccountNumber",    "persAcc");
	ReturnStructure.Insert("ApartmentNumber",                    "flat");
	ReturnStructure.Insert("PhoneNumber",                    "phone");
	ReturnStructure.Insert("PayerKind",                   "payerIdType");
	ReturnStructure.Insert("PayerNumber",                 "payerIdNum");
	ReturnStructure.Insert("FullChildName",                       "childFio");
	ReturnStructure.Insert("BirthDate",                     "birthDate");
	ReturnStructure.Insert("PaymentTerm",                      "paymTerm");
	ReturnStructure.Insert("PayPeriod",                     "paymPeriod");
	ReturnStructure.Insert("PaymentKind",                       "category");
	ReturnStructure.Insert("ServiceCode",                        "serviceName");
	ReturnStructure.Insert("MeterNumber",                "counterId");
	ReturnStructure.Insert("MeteredValue",            "counterVal");
	ReturnStructure.Insert("NotificationNumber",                   "quittId");
	ReturnStructure.Insert("NotificationDate",                    "quittDate");
	ReturnStructure.Insert("InstitutionNumber",                  "instNum");
	ReturnStructure.Insert("GroupNumber",                      "classNum");
	ReturnStructure.Insert("FullTeacherName",                 "specFio");
	ReturnStructure.Insert("InsuranceAmount",                   "addAmount");
	ReturnStructure.Insert("OrderNumber",               "ruleId");
	ReturnStructure.Insert("EnforcementOrderNumber", "execId");
	ReturnStructure.Insert("PaymentKindCode",                   "regType");
	ReturnStructure.Insert("AccrualID",          "uin");
	ReturnStructure.Insert("TechnicalCode",                   "TechCode");
	
	Return ReturnStructure;
	
EndFunction

Function QRCodeGenerationComponent()
	
	ErrorText = NStr("ru = 'Не удалось подключить внешнюю компоненту для генерации QR-кода. Подробности в журнале регистрации.'; en = 'Failed to attach the add-in to generate a QR code. See the event log for details.'; pl = 'Nie udało się podłączyć zewnętrzny składnik do generowania kodu QR. Szczegóły w dzienniku rejestracji.';es_ES = 'No se puede conectar un componente externo para generar el código QR. Véase más en el registro de eventos.';es_CO = 'No se puede conectar un componente externo para generar el código QR. Véase más en el registro de eventos.';tr = 'QR kodu oluşturmak için harici bir bileşen bağlanamadı. Kayıt defterindeki ayrıntılar.';it = 'Impossibile connettere la componente esterna per generare QR code. Consultare registro eventi per ulteriori dettagli.';de = 'Es war nicht möglich, eine externe Komponente anzuschließen, um einen QR-Code zu generieren. Details im Ereignisprotokoll.'");
	
	QRCodeGenerator = Common.AttachAddInFromTemplate("QRCodeExtension", "CommonTemplate.QRCodePrintingComponent");
	If QRCodeGenerator = Undefined Then 
		CommonClientServer.MessageToUser(ErrorText);
	EndIf;
	
	Return QRCodeGenerator;
	
EndFunction

Procedure AddRequiredAttributes(DataStructure)
	
	DataStructure.Insert("RecipientText");
	DataStructure.Insert("RecipientAccountNumber");
	DataStructure.Insert("RecipientBankDescription");
	DataStructure.Insert("RecipientBankBIC");
	DataStructure.Insert("RecipientBankAccount");
	
EndProcedure

Procedure AddAdditionalAttributes(DataStructure)
	
	DataStructure.Insert("AmountAsNumber");
	DataStructure.Insert("PaymentPurpose");
	DataStructure.Insert("RecipientTIN");
	DataStructure.Insert("PayerTIN");
	DataStructure.Insert("AuthorStatus");
	DataStructure.Insert("RecipientCRTR");
	DataStructure.Insert("BCCode");
	DataStructure.Insert("RNCMTCode");
	DataStructure.Insert("BasisIndicator");
	DataStructure.Insert("PeriodIndicator");
	DataStructure.Insert("NumberIndicator");
	DataStructure.Insert("DateIndicator");
	DataStructure.Insert("TypeIndicator");
	
EndProcedure

Procedure AddOtherAdditionalAttributes(DataStructure)
	
	DataStructure.Insert("LastPayerName");
	DataStructure.Insert("PayerName");
	DataStructure.Insert("PayerPatronymic");
	DataStructure.Insert("PayerAddress");
	DataStructure.Insert("BudgetPayeeAccount");
	DataStructure.Insert("PaymentDocumentIndex");
	DataStructure.Insert("IIAN");
	DataStructure.Insert("ContractNumber");
	DataStructure.Insert("PayerAccountNumber");
	DataStructure.Insert("ApartmentNumber");
	DataStructure.Insert("PhoneNumber");
	DataStructure.Insert("PayerKind");
	DataStructure.Insert("PayerNumber");
	DataStructure.Insert("FullChildName");
	DataStructure.Insert("BirthDate");
	DataStructure.Insert("PaymentTerm");
	DataStructure.Insert("PayPeriod");
	DataStructure.Insert("PaymentKind");
	DataStructure.Insert("ServiceCode");
	DataStructure.Insert("MeterNumber");
	DataStructure.Insert("MeteredValue");
	DataStructure.Insert("NotificationNumber");
	DataStructure.Insert("NotificationDate");
	DataStructure.Insert("InstitutionNumber");
	DataStructure.Insert("GroupNumber");
	DataStructure.Insert("FullTeacherName");
	DataStructure.Insert("InsuranceAmount");
	DataStructure.Insert("OrderNumber");
	DataStructure.Insert("EnforcementOrderNumber");
	DataStructure.Insert("PaymentKindCode");
	DataStructure.Insert("AccrualID");
	DataStructure.Insert("TechnicalCode");
	
EndProcedure

Procedure MessagePrintFormUnavailable(Object)
	MessageText = StringFunctionsClientServer.SubstituteParametersToString(NStr("ru = 'Печать %1 не выполнена: выбранная печатная форма недоступна.'; en = 'Cannot print %1: the selected print form is unavailable.'; pl = '%1 nie został wydrukowany. Wybrany formularz wydruku jest niedostępny.';es_ES = '%1 no se ha imprimido. La versión impresa seleccionada no está disponible.';es_CO = '%1 no se ha imprimido. La versión impresa seleccionada no está disponible.';tr = '%1 yazdırılamadı: Seçilen yazdırma formu mevcut değil.';it = 'Impossibile stampare %1: il modulo selezionato non è disponibile.';de = '%1 wurde nicht gedruckt. Das ausgewählte Druckformular ist nicht verfügbar.'"), Object);
	CommonClientServer.MessageToUser(MessageText, Object);
EndProcedure

// Generates a document package for sending to the printer.
Function DocumentsPackage(SpreadsheetDocuments, PrintObjects, PrintInSets, CopiesCount = 1) Export
	
	DocumentsPackageToDisplay = New RepresentableDocumentBatch;
	DocumentsPackageToDisplay.Collate = True;
	PrintFormsCollection = SpreadsheetDocuments.UnloadValues();
	
	For Each PrintForm In PrintFormsCollection Do
		PrintInSets = PrintInSets Or PrintForm.DuplexPrinting <> DuplexPrintingType.None;
	EndDo;
	
	If PrintInSets AND PrintObjects.Count() > 1 Then 
		For Each PrintObject In PrintObjects Do
			AreaName = PrintObject.Presentation;
			For Each PrintForm In PrintFormsCollection Do
				Area = PrintForm.Areas.Find(AreaName);
				If Area = Undefined Then
					Continue;
				EndIf;
				
				SpreadsheetDocument = PrintForm.GetArea(Area.Top, , Area.Bottom);
				FillPropertyValues(SpreadsheetDocument, PrintForm, SpreadsheetDocumentPropertiesToCopy());
				
				DocumentsPackageToDisplay.Content.Add().Data = PackageWithOneSpreadsheetDocument(SpreadsheetDocument);
			EndDo;
		EndDo;
	Else
		For Each PrintForm In PrintFormsCollection Do
			SpreadsheetDocument = New SpreadsheetDocument;
			SpreadsheetDocument.Put(PrintForm);
			FillPropertyValues(SpreadsheetDocument, PrintForm, SpreadsheetDocumentPropertiesToCopy());
			DocumentsPackageToDisplay.Content.Add().Data = PackageWithOneSpreadsheetDocument(SpreadsheetDocument);
		EndDo;
	EndIf;
	
	SetsPackage = New RepresentableDocumentBatch;
	SetsPackage.Collate = True;
	For Number = 1 To CopiesCount Do
		SetsPackage.Content.Add().Data = DocumentsPackageToDisplay;
	EndDo;
	
	Return SetsPackage;
	
EndFunction

// Wraps a spreadsheet document in a package of displayed documents.
Function PackageWithOneSpreadsheetDocument(SpreadsheetDocument)
	SpreadsheetDocumentAddressInTempStorage = PutToTempStorage(SpreadsheetDocument);
	PackageWithOneDocument = New RepresentableDocumentBatch;
	PackageWithOneDocument.Collate = True;
	PackageWithOneDocument.Content.Add(SpreadsheetDocumentAddressInTempStorage);
	FillPropertyValues(PackageWithOneDocument, SpreadsheetDocument, "Output, DuplexPrinting, PrinterName, Copies, PrintAccuracy");
	If SpreadsheetDocument.Collate <> Undefined Then
		PackageWithOneDocument.Collate = SpreadsheetDocument.Collate;
	EndIf;
	Return PackageWithOneDocument;
EndFunction

// Generates a list of print commands from several objects.
Procedure FillPrintCommandsForObjectsList(ObjectsList, PrintCommands)
	PrintCommandsSources = PrintCommandsSources();
	For Each MetadataObject In ObjectsList Do
		If PrintCommandsSources.Find(MetadataObject) = Undefined Then
			Continue;
		EndIf;
		
		FormPrintCommands = ObjectPrintCommands(MetadataObject);
		
		For Each PrintCommandToAdd In FormPrintCommands Do
			// Searching for a similar command that was added earlier.
			FoundCommands = New Array;
			For Each ExistingPrintCommand In PrintCommands Do
				If ExistingPrintCommand.UUID = PrintCommandToAdd.UUID Then
					FoundCommands.Add(ExistingPrintCommand);
				EndIf;
			EndDo;
			
			If FoundCommands.Count() > 0 Then
				For Each ExistingPrintCommand In FoundCommands Do
					// If the command is in the list, supplement the object types, for which it is intended.
					ObjectType = Type(StrReplace(MetadataObject.FullName(), ".", "Ref."));
					If ExistingPrintCommand.PrintObjectsTypes.Find(ObjectType) = Undefined Then
						ExistingPrintCommand.PrintObjectsTypes.Add(ObjectType);
					EndIf;
					// Clearing PrintManager if it is different for the existing command.
					If ExistingPrintCommand.PrintManager <> PrintCommandToAdd.PrintManager Then
						ExistingPrintCommand.PrintManager = "";
					EndIf;
				EndDo;
				Continue;
			EndIf;
			
			If PrintCommandToAdd.PrintObjectsTypes.Count() = 0 Then
				PrintCommandToAdd.PrintObjectsTypes.Add(Type(StrReplace(MetadataObject.FullName(), ".", "Ref.")));
			EndIf;
			FillPropertyValues(PrintCommands.Add(), PrintCommandToAdd);
		EndDo;
	EndDo;
EndProcedure

// For internal use only.
//
Function CountOfUsedUserTemplates()
	
	Query = New Query;
	Query.Text =
	"SELECT
	|	UserPrintTemplates.TemplateName
	|FROM
	|	InformationRegister.UserPrintTemplates AS UserPrintTemplates
	|WHERE
	|	UserPrintTemplates.Use = TRUE";
	
	Result = Query.Execute().Unload();
	
	Return Result.Count();
	
EndFunction

Procedure SetPrintCommandsSettings(PrintCommands, Owner)
	
	SetPrivilegedMode(True);
	
	QueryText =
	"SELECT
	|	PrintCommandsSettings.UUID
	|FROM
	|	InformationRegister.PrintCommandsSettings AS PrintCommandsSettings
	|WHERE
	|	PrintCommandsSettings.Owner = &Owner
	|	AND PrintCommandsSettings.Visible = FALSE";
	
	Query = New Query(QueryText);
	Query.SetParameter("Owner", Owner);
	ListOfDisabledItems = Query.Execute().Unload().UnloadColumn("UUID");
	
	For Each PrintCommand In PrintCommands Do
		PrintCommand.UUID = PrintCommandUUID(PrintCommand);
		If ListOfDisabledItems.Find(PrintCommand.UUID) <> Undefined Then
			PrintCommand.Disabled = True;
		EndIf;
	EndDo;
	
EndProcedure

Function PrintCommandUUID(PrintCommand)
	
	Parameters = New Array;
	Parameters.Add("ID");
	Parameters.Add("PrintManager");
	Parameters.Add("Handler");
	Parameters.Add("SkipPreview");
	Parameters.Add("SaveFormat");
	Parameters.Add("FixedSet");
	Parameters.Add("AdditionalParameters");
	
	ParametersStructure = New Structure(StrConcat(Parameters, ","));
	FillPropertyValues(ParametersStructure, PrintCommand);
	
	Return Common.CheckSumString(ParametersStructure);
	
EndFunction

Function ObjectPrintCommands(MetadataObject) Export
	PrintCommands = CreatePrintCommandsCollection();
	
	Sources = AttachableCommands.CommandsSourcesTree();
	APISettings = AttachableCommands.AttachableObjectsInterfaceSettings();
	AttachedReportsAndDataProcessors = AttachableCommands.AttachableObjectsTable(APISettings);
	Source = AttachableCommands.RegisterSource(MetadataObject, Sources, AttachedReportsAndDataProcessors, APISettings);
	If Source.Manager = Undefined Then
		Return PrintCommands;
	EndIf;
	
	PrintCommandsToAdd = CreatePrintCommandsCollection();
	Source.Manager.AddPrintCommands(PrintCommandsToAdd);
	For Each PrintCommand In PrintCommandsToAdd Do
		If PrintCommand.PrintManager = Undefined Then
			PrintCommand.PrintManager = Source.FullName;
		EndIf;
		If PrintCommand.Order = 0 Then
			PrintCommand.Order = 50;
		EndIf;
		FillPropertyValues(PrintCommands.Add(), PrintCommand);
	EndDo;
	
	If Common.SubsystemExists("StandardSubsystems.AdditionalReportsAndDataProcessors") Then
		ModuleAdditionalReportsAndDataProcessors = Common.CommonModule("AdditionalReportsAndDataProcessors");
		ModuleAdditionalReportsAndDataProcessors.OnReceivePrintCommands(PrintCommands, Source.FullName);
	EndIf;
	
	FoundItems = AttachedReportsAndDataProcessors.FindRows(New Structure("AddPrintCommands", True));
	For Each AttachedObject In FoundItems Do
		AttachedObject.Manager.AddPrintCommands(PrintCommands);
		AddedCommands = PrintCommands.FindRows(New Structure("PrintManager", Undefined));
		For Each Command In AddedCommands Do
			Command.PrintManager = AttachedObject.FullName;
		EndDo;
	EndDo;
	
	For Each PrintCommand In PrintCommands Do
		PrintCommand.AdditionalParameters.Insert("AddExternalPrintFormsToSet", PrintCommand.AddExternalPrintFormsToSet);
	EndDo;
	
	PrintCommands.Sort("Order Asc, Presentation Asc");
	SetPrintCommandsSettings(PrintCommands, Source.MetadataRef);
	DefinePrintCommandsVisibilityByFunctionalOptions(PrintCommands);
	
	Return PrintCommands;
EndFunction

Procedure CheckSpreadsheetDocumentLayoutByPrintObjects(SpreadsheetDocument, PrintObjects, Val PrintManager, Val ID)
	
	If SpreadsheetDocument.TableHeight = 0 Or PrintObjects.Count() = 0 Then
		Return;
	EndIf;
	
	HasLayoutByPrintObjects = False;
	For Each PrintObject In PrintObjects Do
		For Each Area In SpreadsheetDocument.Areas Do
			If Area.Name = PrintObject.Presentation Then
				HasLayoutByPrintObjects = True;
				Break;
			EndIf;
		EndDo;
	EndDo;
	
	If StrFind(ID, ".") > 0 Then
		Position = StrFind(ID, ".", SearchDirection.FromEnd);
		PrintManager = Left(ID, Position - 1);
		ID = Mid(ID, Position + 1);
	EndIf;
	
	LayoutErrorText = StringFunctionsClientServer.SubstituteParametersToString(NStr(
		"ru = 'Отсутствует разметка табличного документа ""%1"" по объектам печати.
		|Необходимо использовать процедуру PrintManagement.SetDocumentPrintArea()
		|при формировании табличного документа'; 
		|en = 'No ""%1"" spreadsheet document layout by print objects.
		|Use the PrintManagement.SetDocumentPrintArea() procedure
		|when generating the spreadsheet document'; 
		|pl = 'Brak oznaczenia tabelarycznego dokumentu ""%1"" po obiektach wydruku. 
		|Należy stosować procedurę PrintManagement.SetDocumentPrintArea()
		|przy tworzeniu dokumentu tabelarycznego';
		|es_ES = 'No hay marcas del documento de tabla ""%1"" por objetos de impresión.
		|Es necesario usar el procedimientos PrintManagement.SetDocumentPrintArea()
		|al generar el documento de tabla';
		|es_CO = 'No hay marcas del documento de tabla ""%1"" por objetos de impresión.
		|Es necesario usar el procedimientos PrintManagement.SetDocumentPrintArea()
		|al generar el documento de tabla';
		|tr = '""%1"" tablo belgesinde biçimlendirme yok. 
		| Tablo belgesi oluşturulduğunda YazdırmaYönetimi.BelgeYazdırmaAlanınıBelirle()
		| prosedürü kullanılmalıdır';
		|it = 'Nessun layout di foglio di calcolo ""%1"" per gli oggetti di stampa.
		|Usa la procedura PrintManagement.SetDocumentPrintArea()
		| per generare il foglio di calcolo';
		|de = 'Es gibt keine Markierung des Tabellen-Dokuments ""%1"" auf den Druckobjekten,
		|Es ist notwendig, die Prozedur DruckManagement.FestlegenDesDokumentenDruckBereich()
		|beim Erstellen eines tabellarischen Dokuments zu verwenden'"), ID);
	CommonClientServer.Validate(HasLayoutByPrintObjects, LayoutErrorText, PrintManager + "." + "Print()");
	
EndProcedure

Function TemplateNameParts(FullTemplateName)
	StringParts = StrSplit(FullTemplateName, ".");
	LastItemIndex = StringParts.UBound();
	TemplateName = StringParts[LastItemIndex];
	StringParts.Delete(LastItemIndex);
	ObjectName = StrConcat(StringParts, ".");
	
	Result = New Structure;
	Result.Insert("TemplateName", TemplateName);
	Result.Insert("ObjectName", ObjectName);
	
	Return Result;
EndFunction

Function SpreadsheetDocumentPropertiesToCopy() Export
	Return "FitToPage,Output,PageHeight,DuplexPrinting,Protection,PrinterName,LanguageCode,Copies,PrintScale,FirstPageNumber,PageOrientation,TopMargin,LeftMargin,BottomMargin,RightMargin,Collate,HeaderSize,FooterSize,PageSize,PrintAccuracy,BackgroundPicture,BlackAndWhite,PageWidth,PerPage";
EndFunction

Function TemplatesDiffer(Val InitialTemplate, ModifiedTemplate) Export
	Return Common.CheckSumString(NormalizeTemplate(InitialTemplate)) <> Common.CheckSumString(NormalizeTemplate(ModifiedTemplate));
EndFunction

Function NormalizeTemplate(Val Template)
	TemplateStorage = New ValueStorage(Template);
	Return TemplateStorage.Get();
EndFunction

Function AreaTypeSpecifiedIncorrectlyText()
	Return NStr("ru = 'Тип области не указан или указан некорректно.'; en = 'Area type is not specified or specified incorrectly.'; pl = 'Nie określono typu obszaru, lub określono go niepopranie.';es_ES = 'Tipo de área no está especificado o especificado de forma incorrecta.';es_CO = 'Tipo de área no está especificado o especificado de forma incorrecta.';tr = 'Alan tipi yanlış belirtilmemiş veya belirtilmemiş.';it = 'Il tipo di area non viene specificato o specificato in modo non corretto.';de = 'Der Bereichstyp wurde nicht angegeben oder falsch angegeben.'");
EndFunction

Function AreasSignaturesAndSeals(PrintObjects) Export
	
	SignaturesAndSeals = ObjectsSignaturesAndSeals(PrintObjects);
	
	AreasSignaturesAndSeals = New Map;
	For Each PrintObject In PrintObjects Do
		ObjectRef = PrintObject.Value;
		SignaturesAndSealsSet = SignaturesAndSeals[ObjectRef];
		AreasSignaturesAndSeals.Insert(PrintObject.Presentation, SignaturesAndSealsSet);
	EndDo;
	
	Return AreasSignaturesAndSeals;
	
EndFunction

Function ObjectsSignaturesAndSeals(Val PrintObjects) Export
	
	ObjectsList = PrintObjects.UnloadValues();
	SignaturesAndSeals = New Map;
	PrintManagementOverridable.OnGetSignaturesAndSeals(ObjectsList, SignaturesAndSeals);
	
	Return SignaturesAndSeals;
	
EndFunction

Procedure AddSignatureAndSeal(SpreadsheetDocument, AreasSignaturesAndSeals) Export
	
	For Each Drawing In SpreadsheetDocument.Drawings Do
		Position = StrFind(Drawing.Name, "_Document_");
		If Position > 0 Then
			ObjectAreaName = Mid(Drawing.Name, Position + 1);
			
			SignaturesAndSealsSet = AreasSignaturesAndSeals[ObjectAreaName];
			If SignaturesAndSealsSet = Undefined Then
				Continue;
			EndIf;
			
			Picture = SignaturesAndSealsSet[Left(Drawing.Name, Position - 1)];
			If Picture <> Undefined Then
				Drawing.Picture = Picture;
			EndIf;
			Drawing.Line = New Line(SpreadsheetDocumentDrawingLineType.None);
		EndIf;
	EndDo;

EndProcedure

Procedure RemoveSignatureAndSeal(SpreadsheetDocument, HideSignaturesAndSeals = False) Export
	
	DrawingsToDelete = New Array;
	For Each Drawing In SpreadsheetDocument.Drawings Do
		If IsSignatureOrSeal(Drawing) Then
			Drawing.Picture = New Picture;
			Drawing.Line = New Line(SpreadsheetDocumentDrawingLineType.None);
			If HideSignaturesAndSeals Then
				DrawingsToDelete.Add(Drawing);
			EndIf;
		EndIf;
	EndDo;
	
	For Each Drawing In DrawingsToDelete Do
		SpreadsheetDocument.Drawings.Delete(Drawing);
	EndDo;
	
EndProcedure

Function IsSignatureOrSeal(Drawing) Export
	
	Return Drawing.DrawingType = SpreadsheetDocumentDrawingType.Picture AND StrFind(Drawing.Name, "_Document_") > 0;
	
EndFunction

Function GenerateExternalPrintForm(AdditionalDataProcessorRef, ID, ObjectsList)
	
	SourceParameters = New Structure;
	SourceParameters.Insert("CommandID", ID);
	SourceParameters.Insert("RelatedObjects", ObjectsList);
	
	PrintFormsCollection = Undefined;
	PrintObjects = New ValueList;
	OutputParameters = PrepareOutputParametersStructure();
	
	PrintByExternalSource(AdditionalDataProcessorRef, SourceParameters, PrintFormsCollection,
	PrintObjects, OutputParameters);
	
	Result = New Structure;
	Result.Insert("PrintFormsCollection", PrintFormsCollection);
	Result.Insert("PrintObjects", PrintObjects);
	Result.Insert("OutputParameters", OutputParameters);
	
	Return Result;
	
EndFunction

Procedure InsertPicturesToHTML(HTMLFileName) Export
	
	TextDocument = New TextDocument();
	TextDocument.Read(HTMLFileName, TextEncoding.UTF8);
	HTMLText = TextDocument.GetText();
	
	HTMLFile = New File(HTMLFileName);
	
	PicturesFolderName = HTMLFile.BaseName + "_files";
	PicturesFolderPath = StrReplace(HTMLFile.FullName, HTMLFile.Name, PicturesFolderName);
	
	// The folder is only for pictures.
	PicturesFiles = FindFiles(PicturesFolderPath, "*");
	
	For Each PicturesFile In PicturesFiles Do
		PictureInText = Base64String(New BinaryData(PicturesFile.FullName));
		PictureInText = "data:image/" + Mid(PicturesFile.Extension,2) + ";base64," + Chars.LF + PictureInText;
		
		HTMLText = StrReplace(HTMLText, PicturesFolderName + "\" + PicturesFile.Name, PictureInText);
	EndDo;
		
	TextDocument.SetText(HTMLText);
	TextDocument.Write(HTMLFileName, TextEncoding.UTF8);
	
EndProcedure

Function FileName(FilePath)
	File = New File(FilePath);
	Return File.Name;
EndFunction

Function PackToArchive(FilesList)
	
	If FilesList.Count() = 0 Then
		Return Undefined;
	EndIf;
	
	MemoryStream = New MemoryStream;
	ZipFileWriter = New ZipFileWriter(MemoryStream);
	
	TempFolder = FileSystem.CreateTemporaryDirectory();
	
	CreateDirectory(TempFolder);
	
	For Each File In FilesList Do
		FileName = TempFolder + File.FileName;
		FileName = UniqueFileName(FileName);
		File.BinaryData.Write(FileName);
		ZipFileWriter.Add(FileName);
	EndDo;
	
	ZipFileWriter.Write();
	MemoryStream.Seek(0, PositionInStream.Begin);
	
	DataReading = New DataReader(MemoryStream);
	DataReadingResult = DataReading.Read();
	BinaryData = DataReadingResult.GetBinaryData();
	
	DataReading.Close();
	MemoryStream.Close();
	
	FileSystem.DeleteTemporaryDirectory(TempFolder);
	
	Return BinaryData;
	
EndFunction

Function UniqueFileName(FileName)
	
	File = New File(FileName);
	NameWithoutExtension = File.BaseName;
	Extension = File.Extension;
	Folder = File.Path;
	
	Counter = 1;
	While File.Exist() Do
		Counter = Counter + 1;
		File = New File(Folder + NameWithoutExtension + " (" + Counter + ")" + Extension);
	EndDo;
	
	Return File.FullName;

EndFunction

Function SpreadsheetDocumentToBinaryData(SpreadsheetDocument, Format)
	
	TempFileName = GetTempFileName();
	SpreadsheetDocument.Write(TempFileName, Format);
	
	If Format = SpreadsheetDocumentFileType.HTML Then
		InsertPicturesToHTML(TempFileName);
	EndIf;
	
	BinaryData = New BinaryData(TempFileName);
	
	Return BinaryData;
	
EndFunction

Function PrintFormsByObjects(PrintForm, PrintObjects) Export
	
	If PrintObjects.Count() = 0 Then
		Return New Structure("PrintObjectsNotSpecified", PrintForm);
	EndIf;
	
	Result = New Map;
	
	For Each PrintObject In PrintObjects Do
		AreaName = PrintObject.Presentation;
		Area = PrintForm.Areas.Find(AreaName);
		If Area = Undefined Then
			Continue;
		EndIf;
		
		If PrintObjects.Count() = 1 Then
			SpreadsheetDocument = PrintForm;
		Else
			SpreadsheetDocument = PrintForm.GetArea(Area.Top, , Area.Bottom);
			FillPropertyValues(SpreadsheetDocument, PrintForm, SpreadsheetDocumentPropertiesToCopy());
		EndIf;
		
		Result.Insert(PrintObject.Value, SpreadsheetDocument);
	EndDo;
	
	Return Result;
	
EndFunction

Function ObjectPrintFormFileName(PrintObject, PrintFormFileName, PrintFormName) Export
	
	If PrintObject = Undefined Or PrintObject = "PrintObjectsNotSpecified" Then
		If ValueIsFilled(PrintFormName) Then
			Return PrintFormName;
		EndIf;
		Return GetTempFileName();
	EndIf;
	
	If TypeOf(PrintFormFileName) = Type("Map") Then
		Return String(PrintFormFileName[PrintObject]);
	ElsIf TypeOf(PrintFormFileName) = Type("String") AND Not IsBlankString(PrintFormFileName) Then
		Return PrintFormFileName;
	EndIf;
	
	Return DefaultPrintFormFileName(PrintObject, PrintFormName);
	
EndFunction

Function DefaultPrintFormFileName(PrintObject, PrintFormName)
	
	If Common.IsDocument(Metadata.FindByType(TypeOf(PrintObject))) Then
		
		DocumentContainsNumber = PrintObject.Metadata().NumberLength > 0;
		
		If DocumentContainsNumber Then
			AttributesList = "Date,Number";
			Template = NStr("ru = '[PrintFormName] № [Number] от [Date]'; en = '[PrintFormName] No. [Number], [Date]'; pl = '[PrintFormName] nr [Number], [Date]';es_ES = '[PrintFormName] No. [Number], [Date]';es_CO = '[PrintFormName] No. [Number], [Date]';tr = '[PrintFormName] No. [Number], [Date]';it = '[PrintFormName] No. [Number],[Date]';de = '[PrintFormName] Nr. [Number], [Date]'");
		Else
			AttributesList = "Date";
			Template = NStr("ru = '[PrintFormName] от [Date]'; en = '[PrintFormName],  [Date]'; pl = '[PrintFormName],  [Date]';es_ES = '[PrintFormName],  [Date]';es_CO = '[PrintFormName],  [Date]';tr = '[PrintFormName],  [Date]';it = '[PrintFormName], [Date]';de = '[PrintFormName], [Date]'");
		EndIf;
		
		ParametersToInsert = Common.ObjectAttributesValues(PrintObject, AttributesList);
		If Common.SubsystemExists("StandardSubsystems.ObjectsPrefixes") AND DocumentContainsNumber Then
			ModuleObjectsPrefixesClientServer = Common.CommonModule("ObjectPrefixationClientServer");
			ParametersToInsert.Number = ModuleObjectsPrefixesClientServer.NumberForPrinting(ParametersToInsert.Number);
		EndIf;
		ParametersToInsert.Date = Format(ParametersToInsert.Date, "DLF=D");
		ParametersToInsert.Insert("PrintFormName", PrintFormName);
		
	Else
		
		ParametersToInsert = New Structure;
		ParametersToInsert.Insert("PrintFormName",PrintFormName);
		ParametersToInsert.Insert("ObjectPresentation", Common.SubjectString(PrintObject));
		ParametersToInsert.Insert("CurrentDate",Format(CurrentSessionDate(), "DLF=D"));
		Template = NStr("ru = '[PrintFormName] - [ObjectPresentation] - [CurrentDate]'; en = '[PrintFormName] - [ObjectPresentation] - [CurrentDate]'; pl = '[PrintFormName] - [ObjectPresentation] - [CurrentDate]';es_ES = '[PrintFormName] - [ObjectPresentation] - [CurrentDate]';es_CO = '[PrintFormName] - [ObjectPresentation] - [CurrentDate]';tr = '[PrintFormName] - [ObjectPresentation] - [CurrentDate]';it = '[PrintFormName] - [ObjectPresentation] - [CurrentDate]';de = '[PrintFormName] - [ObjectPresentation] - [CurrentDate]'");
		
	EndIf;
	
	Return StringFunctionsClientServer.InsertParametersIntoString(Template, ParametersToInsert);
	
EndFunction

Function OfficeDocumentFileName(Val FileName, Val Transliterate = False) Export
	
	FileName = CommonClientServer.ReplaceProhibitedCharsInFileName(FileName);
	
	ExtensionsToExpect = New Map;
	ExtensionsToExpect.Insert(".docx", True);
	ExtensionsToExpect.Insert(".doc", True);
	ExtensionsToExpect.Insert(".odt", True);
	ExtensionsToExpect.Insert(".html", True);
	
	File = New File(FileName);
	If ExtensionsToExpect[File.Extension] = Undefined Then
		FileName = FileName + ".docx";
	EndIf;
	
	If Transliterate Then
		FileName = StringFunctionsClientServer.LatinString(FileName)
	EndIf;
	
	Return FileName;
	
EndFunction

// A list of possible template names:
//  1) in session language
//  2) in configuration language
//  3) without specifying a language.
//
Function TemplateNames(Val TemplateName)
	
	Result = New Array;
	If StrFind(TemplateName, "PF_DOC_") > 0 
		Or StrFind(TemplateName, "PF_ODT_") > 0 Then
		
		CurrentLanguage = CurrentLanguage();
		If TypeOf(CurrentLanguage) <> Type("MetadataObject") Then
			CurrentLanguage = Metadata.DefaultLanguage;
		EndIf;
		LanguageCode = CurrentLanguage.LanguageCode;
		Result.Add(TemplateName + "_" + LanguageCode);
		If LanguageCode <> CommonClientServer.DefaultLanguageCode() Then
			Result.Add(TemplateName + "_" + CommonClientServer.DefaultLanguageCode());
		EndIf;
		
	EndIf;
	Result.Add(TemplateName);
	Return Result;

EndFunction

Function FindTemplate(PathToTemplate)
	
	ErrorText = StringFunctionsClientServer.SubstituteParametersToString(
		NStr("ru = 'Макет %1 не существует. Операция прервана.'; en = 'Layout %1 does not exist. Operation terminated.'; pl = 'Makieta ""%1"" nie istnieje. Operacja została przerwana.';es_ES = 'Ubicación %1no existe. Operación cancelada.';es_CO = 'Ubicación %1no existe. Operación cancelada.';tr = '%1 yerleşimi mevcut değil. İşlem iptal edildi.';it = 'Layout %1 inesistente. Operazione terminata.';de = 'Vorlage ""%1"" existiert nicht. Operation abgebrochen.'"), PathToTemplate);
	PathParts = StrSplit(PathToTemplate, ".", True);
	If PathParts.Count() <> 2 AND PathParts.Count() <> 3 Then
		Raise ErrorText;
	EndIf;
	
	TemplateName = PathParts[PathParts.UBound()];
	PathParts.Delete(PathParts.UBound());
	ObjectName = StrConcat(PathParts, ".");
	
	QueryText = 
	"SELECT
	|	UserPrintTemplates.Template AS Template,
	|	UserPrintTemplates.TemplateName AS TemplateName
	|FROM
	|	InformationRegister.UserPrintTemplates AS UserPrintTemplates
	|WHERE
	|	UserPrintTemplates.Object = &Object
	|	AND UserPrintTemplates.TemplateName LIKE &TemplateName
	|	AND UserPrintTemplates.Use";
	
	Query = New Query(QueryText);
	Query.Parameters.Insert("Object", ObjectName);
	Query.Parameters.Insert("TemplateName", TemplateName + "%");
	
	Selection = Query.Execute().Select();
	
	TemplatesList = New Map;
	While Selection.Next() Do
		TemplatesList.Insert(Selection.TemplateName, Selection.Template.Get());
	EndDo;
	
	SearchNames = TemplateNames(TemplateName);
	
	For Each SearchName In SearchNames Do
		FoundTemplate = TemplatesList[SearchName];
		If FoundTemplate <> Undefined Then
			Return FoundTemplate;
		EndIf;
	EndDo;
	
	IsCommonTemplate = StrSplit(ObjectName, ".").Count() = 1;
	
	TemplatesCollection = Metadata.CommonTemplates;
	If Not IsCommonTemplate Then
		MetadataObject = Metadata.FindByFullName(ObjectName);
		If MetadataObject = Undefined Then
			Raise ErrorText;
		EndIf;
		TemplatesCollection = MetadataObject.Templates;
	EndIf;
	
	For Each SearchName In SearchNames Do
		If TemplatesCollection.Find(SearchName) <> Undefined Then
			If IsCommonTemplate Then
				Return GetCommonTemplate(SearchName);
			Else
				SetSafeModeDisabled(True);
				SetPrivilegedMode(True);
				Return Common.ObjectManagerByFullName(ObjectName).GetTemplate(SearchName);
			EndIf;
		EndIf;
	EndDo;
	
	Raise ErrorText;
		
EndFunction

Procedure ExecutePrintToFileCommand(PrintCommand, SettingsForSaving, ObjectsList, Result)
	
	PrintData = Undefined;
	If PrintCommand.PrintManager = "StandardSubsystems.AdditionalReportsAndDataProcessors" Then
		Source = PrintCommand.AdditionalParameters.Ref;
		PrintData = GenerateExternalPrintForm(Source, PrintCommand.ID, ObjectsList);
	Else
		PrintData = GeneratePrintForms(PrintCommand.PrintManager, PrintCommand.ID,
		ObjectsList, PrintCommand.AdditionalParameters);
	EndIf;
	
	PrintFormsCollection = PrintData.PrintFormsCollection;
	PrintObjects = PrintData.PrintObjects;
	
	AreasSignaturesAndSeals = Undefined;
	If SettingsForSaving.SignatureAndSeal Then
		AreasSignaturesAndSeals = AreasSignaturesAndSeals(PrintObjects);
	EndIf;
	
	FormatsTable = SpreadsheetDocumentSaveFormatsSettings();
	
	For Each PrintForm In PrintFormsCollection Do
		If ValueIsFilled(PrintForm.OfficeDocuments) Then
			For Each OfficeDocument In PrintForm.OfficeDocuments Do
				File = Result.Add();
				File.FileName = OfficeDocumentFileName(OfficeDocument.Value, SettingsForSaving.TransliterateFilesNames);
				File.BinaryData = GetFromTempStorage(OfficeDocument.Key);
			EndDo;
			Continue;
		EndIf;
		
		If SettingsForSaving.SignatureAndSeal Then
			AddSignatureAndSeal(PrintForm.SpreadsheetDocument, AreasSignaturesAndSeals);
		Else
			RemoveSignatureAndSeal(PrintForm.SpreadsheetDocument);
		EndIf;
		
		PrintFormsByObjects = PrintFormsByObjects(PrintForm.SpreadsheetDocument, PrintObjects);
		For Each MapBetweenObjectAndPrintForm In PrintFormsByObjects Do
			
			PrintObject = MapBetweenObjectAndPrintForm.Key;
			SpreadsheetDocument = MapBetweenObjectAndPrintForm.Value;
			
			For Each Format In SettingsForSaving.SaveFormats Do
				FileType = Format;
				If TypeOf(FileType) = Type("String") Then
					FileType = SpreadsheetDocumentFileType[FileType];
				EndIf;
				FormatSettings = FormatsTable.FindRows(New Structure("SpreadsheetDocumentFileType", FileType))[0];
				
				FileExtension = FormatSettings.Extension;
				SpecifiedPrintFormsNames = PrintForm.PrintFormFileName;
				PrintFormName = PrintForm.TemplateSynonym;
				
				FileName = ObjectPrintFormFileName(PrintObject, SpecifiedPrintFormsNames, PrintFormName) + "." + FileExtension;
				If SettingsForSaving.TransliterateFilesNames Then
					FileName = StringFunctionsClientServer.LatinString(FileName)
				EndIf;
				FileName = CommonClientServer.ReplaceProhibitedCharsInFileName(FileName);
				
				File = Result.Add();
				File.FileName = FileName;
				File.BinaryData = SpreadsheetDocumentToBinaryData(SpreadsheetDocument, FileType);
			EndDo;
		EndDo;
	EndDo;
	
EndProcedure

#EndRegion
