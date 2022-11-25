#Region Internal

// Gets the first value of a specified contacts kind from an object.
//
// Parameters:
//     Ref - AnyRef - a reference to an  owner object of contacts (company, counterparty, partner, 
//                                             and so on).
//     ContactInformationType - EnumRef.ContactInformationTypes - the processing parameters.
//     Date - Date - a date on which the value of the contacts will be received.
//
// Returns:
//     String - a string presentation of a value.
//
Function FirstValueOfObjectContactsByType(Ref, ContactInformationType, Date) Export

	Result = "";
	FullName = Ref.Metadata().FullName();

	If StrStartsWith(FullName , NStr("ru = 'Справочник'; en = 'Catalog'; pl = 'Katalog';es_ES = 'Catálogo';es_CO = 'Catálogo';tr = 'Katalog';it = 'Anagrafica';de = 'Katalog'")) Then
		ContactsGroupName = NStr("ru = 'Справочник'; en = 'Catalog'; pl = 'Katalog';es_ES = 'Catálogo';es_CO = 'Catálogo';tr = 'Katalog';it = 'Anagrafica';de = 'Katalog'") + Ref.Metadata().Name;
	ElsIf StrStartsWith(FullName , NStr("ru = 'Документ'; en = 'Document'; pl = 'Dokument';es_ES = 'Documento';es_CO = 'Documento';tr = 'Belge';it = 'Documento';de = 'Dokument'")) Then
		ContactsGroupName = NStr("ru = 'Документ'; en = 'Document'; pl = 'Dokument';es_ES = 'Documento';es_CO = 'Documento';tr = 'Belge';it = 'Documento';de = 'Dokument'") + Ref.Metadata().Name;
	EndIf;
	
	Query = New Query;
	Query.Text = 
		"SELECT
		|	ContactInformationKinds.PredefinedDataName AS Description
		|FROM
		|	Catalog.ContactInformationKinds AS ContactInformationKinds
		|WHERE
		|	ContactInformationKinds.IsFolder = TRUE";
	
	QueryResult = Query.Execute().Select();
	While QueryResult.Next() Do
		If QueryResult.Description = ContactsGroupName Then
			Query = New Query;
			Query.Text = 
				"SELECT
				|	ContactInformationKindsSubordinate.Ref AS Ref
				|FROM
				|	Catalog.ContactInformationKinds AS ContactInformationKinds
				|		LEFT JOIN Catalog.ContactInformationKinds AS ContactInformationKindsSubordinate
				|		ON (ContactInformationKindsSubordinate.Parent = ContactInformationKinds.Ref)
				|WHERE
				|	ContactInformationKinds.PredefinedDataName = &PredefinedDataName
				|	AND ContactInformationKinds.IsFolder = TRUE
				|	AND ContactInformationKindsSubordinate.Type = &Type";
			
			Query.SetParameter("PredefinedDataName", ContactsGroupName);
			Query.SetParameter("Type", ContactInformationType);
			
			QueryResult = Query.Execute().Select();
			If QueryResult.Next() Then
				Result = ContactsManager.ObjectContactInformation(
					Ref, QueryResult.Ref, Date);
			EndIf;
		EndIf;
	EndDo;
	Return Result;

EndFunction

Function CheckAddress(Address, CheckParametersAddresses = Undefined) Export
	
	CheckResult = New Structure("Result, ErrorsList");
	CheckResult.ErrorsList = New ValueList;
	
	If TypeOf(Address) <> Type("String") Then
		CheckResult.Result = "ContainsErrors";
		CheckResult.ErrorsList.Add("AddressFormat", NStr("ru = 'Некорректный формат адреса'; en = 'Invalid address format'; pl = 'Nieprawidłowy format adresu';es_ES = 'Formato incorrecto de la dirección';es_CO = 'Formato incorrecto de la dirección';tr = 'Yanlış adres biçimi';it = 'Formato indirizzo non valido';de = 'Ungültiges Adressformat'"));
		Return CheckResult;
	EndIf;
	
	If Metadata.DataProcessors.Find("AdvancedContactInformationInput") <> Undefined Then
		DataProcessors["AdvancedContactInformationInput"].CheckAddress(Address, CheckResult, CheckParametersAddresses);
	EndIf;
	
	Return CheckResult;
	
EndFunction

////////////////////////////////////////////////////////////////////////////////
// Configuration subsystems event handlers.

// See ObjectVersioningOverridable.OnPrepareObjectData. 
Procedure OnPrepareObjectData(Object, AdditionalAttributes) Export 
	
	If Object.Metadata().TabularSections.Find("ContactInformation") <> Undefined Then
		For Each Contact In ContactsManager.ObjectContactInformation(Object.Ref,, CurrentSessionDate(), False) Do
			If ValueIsFilled(Contact.Kind) Then
				Attribute = AdditionalAttributes.Add();
				Attribute.Description = Contact.Kind.Description;
				Attribute.Value = Contact.Presentation;
			EndIf;
		EndDo;
	EndIf;
	
EndProcedure

// See ImportDataFromFileOverridable.OnDefineCatalogsForDataImport. 
Procedure OnDefineCatalogsForDataImport(CatalogsToImport) Export
	
	// Importing to the country classifier is denied.
	TableRow = CatalogsToImport.Find(Metadata.Catalogs.WorldCountries.FullName(), "FullName");
	If TableRow <> Undefined Then 
		CatalogsToImport.Delete(TableRow);
	EndIf;
	
EndProcedure

// See ObjectsAttributesEditBlockedOverridable.OnDefineObjectsWithLockedAttributes. 
Procedure OnDefineObjectsWithLockedAttributes(Objects) Export
	
	Objects.Insert(Metadata.Catalogs.ContactInformationKinds.FullName(), "");
	
EndProcedure

// See BatchObjectModificationOverridable.OnDetermineObjectsWithEditableAttributes. 
Procedure OnDefineObjectsWithEditableAttributes(Objects) Export
	Objects.Insert(Metadata.Catalogs.ContactInformationKinds.FullName(), "AttributesToSkipInBatchProcessing");
EndProcedure

// See InfobaseUpdateSSL.OnAddUpdateHandlers. 
Procedure OnAddUpdateHandlers(Handlers) Export
	
	// World country data separation
	If Common.DataSeparationEnabled() Then
		Handler = Handlers.Add();
		Handler.Version    = "2.1.4.8";
		Handler.Procedure = "ContactsManagerInternal.SeparatedWorldCountryPrototypePreparation";
		Handler.ExclusiveMode = True;
		Handler.SharedData      = True;
		
		Handler = Handlers.Add();
		Handler.Version    = "2.1.4.8";
		Handler.Procedure = "ContactsManagerInternal.SeparatedWorldCountryUpdateByPrototype";
		Handler.ExclusiveMode = True;
		Handler.SharedData      = False;
	EndIf;
	
	Handler = Handlers.Add();
	Handler.Version    = "2.2.3.34";
	Handler.Procedure = "ContactsManagerInternal.UpdateExistingWorldCountries";
	Handler.ExecutionMode = "Exclusive";
	Handler.SharedData      = False;
	Handler.InitialFilling = True;
	
	Handler = Handlers.Add();
	Handler.Version = "2.3.2.39";
	Handler.ID = New UUID("f663ee3c-68b7-45db-bd6c-eebe6665fc7c");
	Handler.Procedure = "ContactsManagerInternal.DeleteAddressesWithTextFill";
	Handler.Comment = NStr("ru = 'Обновление сведений контактной информации.
		|До завершения обработки некоторая контактная информация может отображаться некорректно.'; 
		|en = 'Update contact information. 
		|Until the processing is complete, some contact information may be shown incorrectly.'; 
		|pl = 'Aktualizacja informacji kontaktowych.
		|Do zakończenia przetwarzania niektóre informacje kontaktowe te mogą nie być wyświetlane poprawnie.';
		|es_ES = 'La actualización de la información de contacto.
		|Hasta la finalización del procesamiento alguna información de contacto puede visualizarse incorrectamente.';
		|es_CO = 'La actualización de la información de contacto.
		|Hasta la finalización del procesamiento alguna información de contacto puede visualizarse incorrectamente.';
		|tr = 'İletişim bilgilerini güncelleyin. 
		|İşlem tamamlanmadan önce, bazı iletişim bilgileri düzgün görüntülenmeyebilir.';
		|it = 'Aggiornamento informazioni di contatto.
		|Fino a quando il processo non sarà completo, alcune informazioni di contatto potrebbero essere mostrate non correttamente.';
		|de = 'Aktualisieren Sie die Kontaktinformationen.
		|Einige Kontaktinformationen werden möglicherweise erst nach Abschluss der Verarbeitung korrekt angezeigt.'");
	Handler.ExecutionMode = "Deferred";
	Handler.InitialFilling = False;
	
	Handler = Handlers.Add();
	Handler.Version = "2.3.2.156";
	Handler.ID = New UUID("143e1eb1-4fce-4cd2-b307-56f759d144d4");
	Handler.Procedure = "ContactsManagerInternal.EditAddressValidityDate";
	Handler.Comment = NStr("ru = 'Обновление сведений контактной информации содержащих адреса с историей.
		|До завершения обработки некоторая контактная информация может отображаться некорректно.'; 
		|en = 'Update contact information containing addresses with history. 
		|Until the processing is complete, some contact information may be shown incorrectly.'; 
		|pl = 'Aktualizacja informacji kontaktowych zawierających adresy z historią.
		|Do zakończenia przetwarzania niektóre informacje kontaktowe mogą nie być wyświetlane poprawnie.';
		|es_ES = 'La actualización de la información de contacto que contiene las direcciones con el historial.
		|Hasta la finalización del procesamiento alguna información de contacto puede visualizarse incorrectamente.';
		|es_CO = 'La actualización de la información de contacto que contiene las direcciones con el historial.
		|Hasta la finalización del procesamiento alguna información de contacto puede visualizarse incorrectamente.';
		|tr = 'Geçmişi olan adresleri içeren iletişim bilgilerini güncelleyin. 
		|İşlem tamamlanmadan önce, bazı iletişim bilgileri düzgün görüntülenmeyebilir.';
		|it = 'Aggiornare informazioni di contatto contenenti indirizzi con cronologia.
		|Fino alla conclusione dell''elaborazione potrebbero essere mostrate alcune informazioni di contatto in modo errato.';
		|de = 'Aktualisieren Sie die Kontaktinformationen für Adressen mit Historie.
		|Einige Kontaktinformationen werden möglicherweise erst nach Abschluss der Verarbeitung korrekt angezeigt.'");
	Handler.ExecutionMode = "Deferred";
	Handler.InitialFilling = False;
	
	Handler = Handlers.Add();
	Handler.Version    = "2.3.1.8";
	Handler.Procedure = "ContactsManagerInternal.UpdatePhoneExtensionSettings";
	Handler.ExecutionMode = "Seamless";
	Handler.SharedData      = False;
	Handler.InitialFilling = True;
	
	Handler = Handlers.Add();
	Handler.Version    = "2.3.1.15";
	Handler.Procedure = "ContactsManagerInternal.SetUsageFlagValue";
	Handler.ExecutionMode = "Seamless";
	Handler.SharedData      = False;
	Handler.InitialFilling = True;
	
	Handler = Handlers.Add();
	Handler.Version          = "2.3.3.15";
	Handler.ID   = New UUID("72f43d1a-9c4f-4789-81a9-e610cd56f8b2");
	Handler.Procedure       = "Catalogs.ContactInformationKinds.FillContactInformationKinds";
	Handler.ExecutionMode = "Deferred";
	Handler.UpdateDataFillingProcedure = "Catalogs.ContactInformationKinds.FillContactInformationKindsWithOtherFieldToProcess";
	Handler.DeferredProcessingQueue = 1;
	Handler.ObjectsToRead      = "Catalog.ContactInformationKinds";
	Handler.ObjectsToChange    = "Catalog.ContactInformationKinds";
	Handler.ObjectsToLock   = "Catalog.ContactInformationKinds";
	Handler.ExecutionPriorities = InfobaseUpdate.HandlerExecutionPriorities();
	Handler.CheckProcedure    = "InfobaseUpdate.DataUpdatedForNewApplicationVersion";
	Handler.Comment = NStr("ru = 'Заполнение значения поля ""Другое"" у видов контактной информации.
		|До завершения обработки поля ""Другое"" документов в ряде случаев будут отображаться некорректно.'; 
		|en = 'Fill in the Other field value for contact information kinds.
		|Until the processing is complete, the Other field of documents may be shown incorrectly.'; 
		|pl = 'Wypełnienie pola ""Inne"" w rodzajach informacji kontaktowej.
		|Do zakończenia przetwarzania pola ""Inne"" dokumenty w szeregu przypadków mogą nie być wyświetlane poprawnie.';
		|es_ES = 'El relleno del valor del campo ""Otro"" para los tipos de la información de contacto.
		|Hasta la finalización del procesamiento los campo ""Otro"" de los documentos en algunos casos pueden visualizarse incorrectamente.';
		|es_CO = 'El relleno del valor del campo ""Otro"" para los tipos de la información de contacto.
		|Hasta la finalización del procesamiento los campo ""Otro"" de los documentos en algunos casos pueden visualizarse incorrectamente.';
		|tr = 'İletişim bilgileri türlerinde ""Diğer"" alanın değerini doldurun. 
		|Diğer belge alanları işleme tamamlanmadan önce, bazı durumlarda düzgün görüntülenmez.';
		|it = 'Compilare il valore del campo Altro per i tipi di informazioni di contatto.
		|Fino alla conclusione dell''elaborazione, il campo Altro dei documenti potrebbe essere mostrato in modo errato.';
		|de = 'Geben Sie den Wert des Feldes ""Andere"" in die Art der Kontaktinformationen ein.
		|Bis die Verarbeitung des Felds ""Anderer"" von Dokumenten abgeschlossen ist, wird es in einigen Fällen falsch angezeigt.'");
	
	Handler = Handlers.Add();
	Handler.Version          = "2.4.3.4";
	Handler.ID   = New UUID("dfc6a0fa-7c7b-4096-9d04-2c67d5eb17a4");
	Handler.Procedure       = "Catalogs.WorldCountries.UpdateWorldCountriesByCountryClassifier";
	Handler.ExecutionMode = "Deferred";
	Handler.UpdateDataFillingProcedure = "Catalogs.WorldCountries.FillCountriesListToProcess";
	Handler.DeferredProcessingQueue = 1;
	Handler.ObjectsToRead    = "Catalog.WorldCountries";
	Handler.ObjectsToChange  = "Catalog.WorldCountries";
	Handler.ObjectsToLock = "Catalog.WorldCountries";
	Handler.CheckProcedure  = "InfobaseUpdate.DataUpdatedForNewApplicationVersion";
	Handler.Comment = NStr("ru = 'Обновление сведений о странах мирах в соответствии с общероссийским классификатором стран мира.
		|До завершения обработки наименование стран в документах в ряде случаев будет отображаться некорректно.'; 
		|en = 'Update information about countries of the world according to the All-Russian Classifier of Countries.
		|Until the processing is complete, names of countries may be shown in the documents incorrectly.'; 
		|pl = 'Aktualizacja informacji o krajach zgodnie z ogólnorosyjskim klasyfikatorem.
		|Do zakończenia przetwarzania nazwy krajów w dokumentach w niektórych przypadkach mogą nie być wyświetlane poprawnie.';
		|es_ES = 'La actualización de la información de los países del mundo según el clasificador nacional de los países del mundo.
		|Hasta la finalización del procesamiento el nombre de los países en los documentos en algunos casos pueden visualizarse incorrectamente.';
		|es_CO = 'La actualización de la información de los países del mundo según el clasificador nacional de los países del mundo.
		|Hasta la finalización del procesamiento el nombre de los países en los documentos en algunos casos pueden visualizarse incorrectamente.';
		|tr = 'Dünya ülkeleri hakkındaki bilgileri, Tekdüzen Rus dünya ülkeleri sınıflandırıcısına göre güncelleyin.
		| İşleme tamamlanmadan önce, bazı durumlarda belgelerdeki ülke adı düzgün görüntülenmez.';
		|it = 'Aggiornare informazioni sui paesi del mondo in base al Classificatore Panrusso dei Paesi.
		|Fino al completamento dell''elaborazione, i nomi dei paesi potrebbero essere mostrati nei documenti in modo errato.';
		|de = 'Aktualisieren Sie die Informationen über die Länder der Welt gemäß des Allrussischen Klassifikators der Länder.
		|Bis zum Abschluss der Verarbeitung können die Namen der Länder in den Dokumenten falsch angezeigt werden.'");
	
EndProcedure

// See InfobaseUpdateOverridable.OnDefineSettings 
Procedure OnDefineObjectsWithInitialFilling(Objects) Export
	
	Objects.Add(Metadata.Catalogs.WorldCountries);
	
EndProcedure

#EndRegion

#Region Private

#Region InfobaseUpdate

Procedure AddressAutoComplete(Val Text, ChoiceData) Export
	
	If Metadata.DataProcessors.Find("AdvancedContactInformationInput") = Undefined Then
		Return;
	EndIf;
	
	AdditionalParameters = New Structure("WebServiceOnly", True);
	Result = DataProcessors["AdvancedContactInformationInput"].LocalityAutoCompleteList(Text, AdditionalParameters);
	If Result.Cancel Then
		Return;
	EndIf;
	
	ChoiceData = Result.Data;
	FormattingAutoCompleteResults(ChoiceData, Text);
	
EndProcedure

Procedure FormattingAutoCompleteResults(ChoiceData, Val Text) Export
	
	ModuleAddressManagerClientServer = Common.CommonModule("AddressManagerClientServer");
	
	// Appearance of search list.
	SearchTextFragments = StrSplit(Text, " ");
	For each DataString In ChoiceData Do
		
		If TypeOf(DataString.Value) = Type("Structure")
			AND DataString.Value.Property("Address") Then
			
			If ValueIsFilled(DataString.Value.Address) Then
				Address = JSONStringToStructure(DataString.Value.Address);
				DataString.Value.Presentation = ModuleAddressManagerClientServer.AddressPresentation(Address, False);
			EndIf;
			BsoleteAddress = Not DataString.Value.Municipal;
		Else
			BsoleteAddress = False;
		EndIf;
		
		Presentation = DataString.Presentation;
		
		For each SearchTextFragment In SearchTextFragments Do
			Position = StrFind(Upper(Presentation), Upper(SearchTextFragment));
			If Position > 0 Then
				Presentation = Left(Presentation, Position - 1) + Chars.LF + Chars.VTab + Mid(Presentation, Position, StrLen(SearchTextFragment)) 
				+ Chars.LF + Mid(Presentation, Position + StrLen(SearchTextFragment));
			EndIf;
		EndDo;
		Set = StrSplit(Presentation, Chars.LF);
		For Counter = 0 To Set.Count() - 1 Do
			If StrStartsWith(Set[Counter], Chars.VTab) Then
				Set[Counter] = New FormattedString(TrimAll(Set[Counter]), New Font(,, True), StyleColors.SuccessResultColor);
			ElsIf BsoleteAddress Then
				Set[Counter] = New FormattedString(Set[Counter],, StyleColors.InaccessibleCellTextColor);
			EndIf;
		EndDo;
		DataString.Presentation = New FormattedString(Set);
		
	EndDo;

EndProcedure

// Shared exclusive handler used to copy world country data from the zero area.
// Keeps the prototype and the data area list -addressees.
//
Procedure SeparatedWorldCountryPrototypePreparation() Export
	
	// Infobase version control
	PrototypeRegisterName = "DeleteWorldCountries";
	If Metadata.InformationRegisters.Find(PrototypeRegisterName) = Undefined Then
		Return;
	EndIf;
	
	If Not Common.SubsystemExists("StandardSubsystems.SaaS") Then
		Return;
	EndIf;
	
	ModuleSaaS = Common.CommonModule("SaaS");
	
	SetPrivilegedMode(True);
	
	// Requesting data from the zero area, creating the prototype with reference accuracy.
	ModuleSaaS.SetSessionSeparation(True, 0);
	Query = New Query("
		|SELECT 
		|	Catalog.Ref             AS Ref,
		|	Catalog.Code                AS Code,
		|	Catalog.Description       AS Description,
		|	Catalog.CodeAlpha2          AS CodeAlpha2,
		|	Catalog.CodeAlpha3          AS CodeAlpha3, 
		|	Catalog.DescriptionFull AS DescriptionFull
		|FROM
		|	Catalog.WorldCountries AS Catalog
		|");
	ReferenceData = Query.Execute().Unload();
	
	ModuleSaaS.SetSessionSeparation(False);
	
	// Saving the prototype
	Set = InformationRegisters[PrototypeRegisterName].CreateRecordSet();
	Set.Add().Value = New ValueStorage(ReferenceData, New Deflation(9));
	InfobaseUpdate.WriteData(Set);
	
EndProcedure

// Separated handler used to copy world country data from the zero area.
// Prototype prepared during the previous step is used here.
//
Procedure SeparatedWorldCountryUpdateByPrototype() Export
	
	// Infobase version control
	PrototypeRegisterName = "DeleteWorldCountries";
	If Metadata.InformationRegisters.Find(PrototypeRegisterName) = Undefined Then
		Return;
	EndIf;
	
	// Locating a prototype for the current data area.
	Query = New Query("
		|SELECT
		|	ReferenceData.Value
		|FROM
		|	InformationRegister.DeleteWorldCountries AS ReferenceData
		|WHERE
		|	ReferenceData.DataArea = 0
		|");
	Result = Query.Execute().Select();
	If NOT Result.Next() Then
		Return;
	EndIf;
	ReferenceData = Result.Value.Get();
	
	Query = New Query("
		|SELECT
		|	Data.Ref             AS Ref,
		|	Data.Code                AS Code,
		|	Data.Description       AS Description,
		|	Data.CodeAlpha2          AS CodeAlpha2,
		|	Data.CodeAlpha3          AS CodeAlpha3, 
		|	Data.DescriptionFull AS DescriptionFull
		|INTO
		|	ReferenceData
		|FROM
		|	&Data AS Data
		|INDEX BY
		|	Ref
		|;///////////////////////////////////////////////////////////////////
		|SELECT 
		|	ReferenceData.Ref             AS Ref,
		|	ReferenceData.Code                AS Code,
		|	ReferenceData.Description       AS Description,
		|	ReferenceData.CodeAlpha2          AS CodeAlpha2,
		|	ReferenceData.CodeAlpha3          AS CodeAlpha3, 
		|	ReferenceData.DescriptionFull AS DescriptionFull
		|FROM
		|	ReferenceData AS ReferenceData
		|LEFT JOIN
		|	Catalog.WorldCountries AS WorldCountries
		|ON
		|	WorldCountries.Ref = ReferenceData.Ref
		|WHERE
		|	WorldCountries.Ref IS NULL
		|");
	Query.SetParameter("Data", ReferenceData);
	Selection = Query.Execute().Select();
	
	While Selection.Next() Do
		Country = Catalogs.WorldCountries.CreateItem();
		Country.SetNewObjectRef(Selection.Ref);
		FillPropertyValues(Country, Selection, , "Ref");
		InfobaseUpdate.WriteData(Country);
	EndDo;
	
EndProcedure

// Updating only the existing country items from the classifier.
Procedure UpdateExistingWorldCountries() Export
	
	AllErrors = "";
	Add = False;
	
	Filter = New Structure("Code");
	
	// Cannot perform comparison in the query due to possible database case-insensitivity.
	For Each ClassifierRow In ContactsManager.ClassifierTable() Do
		Filter.Code = ClassifierRow.Code;
		Selection = Catalogs.WorldCountries.Select(,, Filter);
		CountryFound = Selection.Next();
		If Not CountryFound AND Add Then
			// Adding country
			Country = Catalogs.WorldCountries.CreateItem();
		ElsIf CountryFound AND (
			Selection.Description <> ClassifierRow.Description
			Or Selection.CodeAlpha2 <> ClassifierRow.CodeAlpha2
			Or Selection.CodeAlpha3 <> ClassifierRow.CodeAlpha3
			Or Selection.DescriptionFull <> ClassifierRow.DescriptionFull) Then
			// Editing country
			Country = Selection.GetObject();
		Else
			Continue;
		EndIf;
		
		BeginTransaction();
		Try
			If Not Country.IsNew() Then
				LockDataForEdit(Country.Ref);
			EndIf;
			FillPropertyValues(Country, ClassifierRow, "Code, Description, CodeAlpha2, CodeAlpha3, DescriptionFull");		
			Country.AdditionalProperties.Insert("DoNotCheckUniqueness");
			Country.Write();
			CommitTransaction();
		Except
			RollbackTransaction();
			Info = ErrorInfo();
			ErrorText = StringFunctionsClientServer.SubstituteParametersToString(NStr("ru='Ошибка записи страны мира %1 (код %2) при обновлении классификатора, %3'; en = 'Error writing world country %1 (code %2) while updating classifier, %3'; pl = 'Wystąpił błąd podczas zapisywania kraju %1 (kod %2) podczas aktualizacji klasyfikatora, %3';es_ES = 'Ha ocurrido un error al inscribir el país %1 (código %2) durante la actualización del clasificador %3';es_CO = 'Ha ocurrido un error al inscribir el país %1 (código %2) durante la actualización del clasificador %3';tr = 'Sınıflandırıcıyı güncellerken ülke %1(kod%2) yazılırken bir hata oluştu.%3';it = 'Errore della registrazione del paese del mondo %1 (codice%2) durante l''aggiornamento del classificatore, %3';de = 'Beim Schreiben des Landes %1 (Code %2) ist beim Aktualisieren des Klassifikators ein Fehler aufgetreten, %3'"),
				Selection.Code, Selection.Description, BriefErrorDescription(Info));
			WriteLogEvent(InfobaseUpdate.EventLogEvent(), 
				EventLogLevel.Error,,,
				ErrorText + Chars.LF + DetailErrorDescription(Info));
			AllErrors = AllErrors + Chars.LF + ErrorText;
		EndTry;
		
	EndDo;
	
	If Not IsBlankString(AllErrors) Then
		Raise TrimAll(AllErrors);
	EndIf;
	
EndProcedure

Procedure DeleteAddressesWithTextFill(Parameters, BatchSize = 1000) Export
	
	ObjectsWithAddress = Undefined;
	Parameters.Property("ObjectsWithAddress", ObjectsWithAddress);
	If Parameters.ExecutionProgress.TotalObjectCount = 0 Then
		
		// receiving addresses for procesing
		Query = New Query;
		Query.Text = "SELECT DISTINCT
			| ContactInformationKinds.Parent.PredefinedDataName AS PredefinedDataName
			|FROM
			| Catalog.ContactInformationKinds AS ContactInformationKinds
			|WHERE
			| ContactInformationKinds.Type = &Type
			| AND ContactInformationKinds.EditOnlyInDialog = &EditOnlyInDialog";
		Query.SetParameter("EditOnlyInDialog", True);
		Query.SetParameter("Type", Enums.ContactInformationTypes.Address);
		QueryResult = Query.Execute();
		DetailedRecordsSelection = QueryResult.Select();
		QueryText = "";
		Separator = "";
		QueryTemplate = "SELECT
			| TableWithContactInformation.Ref AS Ref
			|FROM
			| %1.%2.ContactInformation AS TableWithContactInformation
			|WHERE
			| TableWithContactInformation.Presentation = &Fill
			|
			|GROUP BY
			| TableWithContactInformation.Ref";
		While DetailedRecordsSelection.Next() Do
			If StrStartsWith(DetailedRecordsSelection.PredefinedDataName, "Catalog") Then
				ObjectName = Mid(DetailedRecordsSelection.PredefinedDataName, 11);
				If Metadata.Catalogs.Find(ObjectName) <> Undefined Then
					QueryText = QueryText + Separator + StringFunctionsClientServer.SubstituteParametersToString(QueryTemplate, "Catalog", ObjectName);
					Separator = " UNION ALL ";
				EndIf;
			EndIf;
		EndDo;
		If IsBlankString(QueryText) Then
			Return;
		EndIf;
		Query = New Query(QueryText);
		Query.Parameters.Insert("Fill", ContactsManagerClientServer.EmptyAddressTextAsHiperlink());
		ObjectsWithAddress = Query.Execute().Unload().UnloadColumn("Ref");
		Parameters.ExecutionProgress.TotalObjectCount = ObjectsWithAddress.Count();
		Parameters.Insert("ObjectsWithAddress", ObjectsWithAddress);
	EndIf;
	
	If ObjectsWithAddress = Undefined OR ObjectsWithAddress.Count() = 0 Then
		Return;
	EndIf;
	
	Position = ObjectsWithAddress.Count() - 1;
	NumberOfProcessed = 0;
	
	While Position >= 0 AND NumberOfProcessed < BatchSize Do
		ContactInformationObject = ObjectsWithAddress.Get(Position).GetObject();
		ContactInformation = ContactInformationObject.ContactInformation;
		ArrayForDeletion = New Array;
		For each ContactInformationRow In ContactInformation Do
			If ContactInformationRow.Type = Enums.ContactInformationTypes.Address
				AND ContactInformationRow.Presentation = ContactsManagerClientServer.EmptyAddressTextAsHiperlink() Then
				ArrayForDeletion.Add(ContactInformationRow);
			EndIf;
		EndDo;
		For each ContactInformationRow In ArrayForDeletion Do
			ContactInformation.Delete(ContactInformationRow);
		EndDo;
		ContactInformationObject.Write();
		ObjectsWithAddress.Delete(Position);
		Position = Position - 1;
		NumberOfProcessed = NumberOfProcessed + 1;
	EndDo;
	If ObjectsWithAddress.Count() > 0 Then
		Parameters.ProcessingCompleted = False;
	EndIf;
	Parameters.ExecutionProgress.ProcessedObjectsCount = Parameters.ExecutionProgress.ProcessedObjectsCount + NumberOfProcessed;
	Parameters.Insert("ObjectsWithAddress", ObjectsWithAddress);
	
EndProcedure

Procedure EditAddressValidityDate(Parameters, BatchSize = 1000) Export
	
	ObjectsWithAddress = Undefined;
	Parameters.Property("ObjectsWithAddress", ObjectsWithAddress);
	If Parameters.ExecutionProgress.TotalObjectCount = 0 Then
		
		// receiving addresses for processing (first pass)
		Query = New Query;
		Query.Text = "SELECT DISTINCT
			| ContactInformationKinds.Parent.PredefinedDataName AS PredefinedDataName
			|FROM
			| Catalog.ContactInformationKinds AS ContactInformationKinds
			|WHERE
			| ContactInformationKinds.StoreChangeHistory = TRUE";
			
		DetailedRecordsSelection = Query.Execute().Select();
		
		QueryText = "";
		Separator = "";
		
		QueryTemplate = "SELECT
			|	TableWithContactInformation.Ref AS Ref
			|FROM
			|	%1.%2.ContactInformation AS TableWithContactInformation
			|WHERE
			|	TableWithContactInformation.Kind.StoreChangeHistory = TRUE
			|	AND TableWithContactInformation.ValidFrom <> DATETIME(1, 1, 1)
			|
			|GROUP BY
			|	TableWithContactInformation.Kind,
			|	TableWithContactInformation.Ref";
		
		While DetailedRecordsSelection.Next() Do
			If StrStartsWith(DetailedRecordsSelection.PredefinedDataName, "Catalog") Then
				ObjectName = Mid(DetailedRecordsSelection.PredefinedDataName, 11);
				If Metadata.Catalogs.Find(ObjectName) <> Undefined Then
					QueryText = QueryText + Separator + StringFunctionsClientServer.SubstituteParametersToString(QueryTemplate, "Catalog", ObjectName);
					Separator = " UNION ALL ";
				EndIf;
			EndIf;
		EndDo;
		
		If IsBlankString(QueryText) Then
			Return;
		EndIf;
		
		Query = New Query(QueryText);
		ObjectsWithAddress = Query.Execute().Unload().UnloadColumn("Ref");
		Parameters.ExecutionProgress.TotalObjectCount = ObjectsWithAddress.Count();
		Parameters.Insert("ObjectsWithAddress", ObjectsWithAddress);
		
	EndIf;
	
	If ObjectsWithAddress = Undefined OR ObjectsWithAddress.Count() = 0 Then
		Return;
	EndIf;
	
	Position = ObjectsWithAddress.Count() - 1;
	NumberOfProcessed = 0;
	
	While Position >= 0 AND NumberOfProcessed < BatchSize Do
		
		ContactInformationObject = ObjectsWithAddress.Get(Position).GetObject();
		ContactInformation = ContactInformationObject.ContactInformation;
		ContactInformationKinds = ContactInformation.Unload(, "Kind");
		ContactInformationKinds.GroupBy("Kind");
		
		WritingObjectRequired = False;
		
		For each ContactInformationKind In ContactInformationKinds  Do
			If NOT ValueIsFilled(ContactInformationKind.Kind)
				OR NOT ContactInformationKind.Kind.StoreChangeHistory Then
					Continue;
			EndIf;
			Filter = New Structure("Kind", ContactInformationKind.Kind);
			FoundRows = ContactInformation.FindRows(Filter);
			
			If FoundRows.Count() = 1 Then
				If ValueIsFilled(FoundRows[0].ValidFrom) Then
					FoundRows[0].ValidFrom = Date(1, 1, 1);
					WritingObjectRequired = True;
				EndIf;
			ElsIf FoundRows.Count() > 0 Then
				
				StringForUpdate = FoundRows[0];
				If NOT ValueIsFilled(StringForUpdate.ValidFrom) Then
					StringForUpdate = Undefined;
				Else
					For Index = 1 To FoundRows.Count() - 1 Do
						If NOT ValueIsFilled(FoundRows[Index].ValidFrom) Then
							StringForUpdate = Undefined;
							Break;
						ElsIf FoundRows[Index].ValidFrom < StringForUpdate.ValidFrom Then
							StringForUpdate = FoundRows[Index];
						EndIf;
					EndDo;
				EndIf;
				If StringForUpdate <> Undefined Then
					StringForUpdate.ValidFrom = Date(1, 1, 1);
					WritingObjectRequired = True;
				EndIf;
			EndIf;
		
		EndDo;
		
		If WritingObjectRequired Then
			ContactInformationObject.Write();
		EndIf;
		
		ObjectsWithAddress.Delete(Position);
		Position = Position - 1;
		NumberOfProcessed = NumberOfProcessed + 1;
	EndDo;
	
	If ObjectsWithAddress.Count() > 0 Then
		Parameters.ProcessingCompleted = False;
	EndIf;
	
	Parameters.ExecutionProgress.ProcessedObjectsCount = Parameters.ExecutionProgress.ProcessedObjectsCount + NumberOfProcessed;
	Parameters.Insert("ObjectsWithAddress", ObjectsWithAddress);
	
EndProcedure

Procedure UpdatePhoneExtensionSettings() Export
	
	// Sets the PhoneWithAdditionalNumber flag for backward compatibility.
	Query = New Query;
	Query.Text = 
		"SELECT
		|	ContactInformationKinds.Ref
		|FROM
		|	Catalog.ContactInformationKinds AS ContactInformationKinds
		|WHERE
		|	ContactInformationKinds.Type =  Value(Enum.ContactInformationTypes.Phone)";
	
	QueryResult = Query.Execute().Select();
	
	While QueryResult.Next() Do
		ContactInformationKind = QueryResult.Ref.GetObject();
		ContactInformationKind.PhoneWithExtension = True;
		InfobaseUpdate.WriteData(ContactInformationKind);
	EndDo;
	
EndProcedure

// Initializes the value of the Used attribute of the ContactsKind catalog.
//
Procedure SetUsageFlagValue() Export
	
	Query = New Query;
	Query.Text = "SELECT
	|	ContactInformationKinds.Ref
	|FROM
	|	Catalog.ContactInformationKinds AS ContactInformationKinds
	|WHERE
	|	NOT ContactInformationKinds.Used";
	
	Result = Query.Execute();
	Selection = Result.Select();
	
	While Selection.Next() Do
		
		ObjectContactsKind = Selection.Ref.GetObject();
		ObjectContactsKind.Used = True;
		InfobaseUpdate.WriteData(ObjectContactsKind);
		
	EndDo;
	
EndProcedure

#EndRegion

#Region CommonInternalProceduresAndFunctions

// Returns a value list
Function AddressesAvailableForCopying(Val FieldsValuesForAnalysis, Val AddressKind) Export
	
	OnlyNationalAddress = AddressKind.OnlyNationalAddress;
	
	Result = New ValueList;
	
	For Each Address In FieldsValuesForAnalysis Do
		AllowedSource = True;
		
		Presentation = Address.Presentation;
		If IsBlankString(Presentation) Then
			// Non-empty presentation
			AllowedSource = False;
		Else
			If OnlyNationalAddress Then
				// Cannot copy a foreign address to a domestic address.
				XMLAddress = ContactsManager.ContactInformationToXML(Address.FieldsValue, Presentation, AddressKind);
				XDTOAddress = ContactsFromXML(XMLAddress, AddressKind);
				If Not IsNationalAddress(XDTOAddress) Then
					AllowedSource = False;
				EndIf;
			EndIf;
		EndIf;
		
		If AllowedSource Then
			Result.Add(Address.ID, String(Address.AddressKind) + ": " + Presentation);
		EndIf;
	EndDo;
	
	Return Result;
EndFunction

Function EventLogEvent()
	
	Return NStr("ru = 'Контактная информация'; en = 'Contact information'; pl = 'Informacje kontaktowe';es_ES = 'Información de contacto';es_CO = 'Información de contacto';tr = 'İletişim bilgileri';it = 'Informazioni di contatto';de = 'Kontakt Informationen'", CommonClientServer.DefaultLanguageCode());
	
EndFunction

// Converts XDTO contact information into XML.
//
//  Parameters:
//      XDTOInformationObject - XDTOObject - contact information.
//
// Returns:
//      String - a conversion result in XML format.
//
Function XDTOContactsInXML(XDTOInformationObject) Export
	
	Record = New XMLWriter;
	Record.SetString(New XMLWriterSettings(, , False, False, ""));
	
	If XDTOInformationObject <> Undefined Then
		XDTOFactory.WriteXML(Record, XDTOInformationObject);
	EndIf;
	
	Result = StrReplace(Record.Close(), Chars.LF, "&#10;");
	Result = StrReplace(Result, "<CityDistrict/>", "");// Compatibility with ARCA
	
	If Metadata.CommonModules.Find("AddressManager") <> Undefined Then
		ModuleAddressManager = Common.CommonModule("AddressManager");
		Result = ModuleAddressManager.BeforeWriteXDTOContactInformation(Result);
	EndIf;
	
	Return Result;
	
EndFunction

// Parses a CI presentation and returns XDTO.
//
//  Parameters:
//      Text - String - XML
//      ExpectedKind - CatalogRef.ContactsKinds, EnumRef.ContactsTypes, Structure.
//
// Returns:
//      String - contact information.
//
Function ContactsByPresentation(Presentation, ExpectedKind, ToStructure = False) Export
	
	ExpectedType = ContactInformationManagementInternalCached.ContactInformationKindType(ExpectedKind);
	
	If ExpectedType = Enums.ContactInformationTypes.Address Then
		
		Return GenerateAddressByPresentation(Presentation, True, ToStructure);
		
	ElsIf ExpectedType = Enums.ContactInformationTypes.Phone
		OR ExpectedType = Enums.ContactInformationTypes.Fax Then
			Return DeserializingPhoneFaxInJSON("", Presentation, ExpectedType);
		
	Else
		
		Contacts = ContactsManagerClientServer.NewContactInformationDetails(ExpectedType);
		Contacts.Value = Presentation;
		Return Contacts;
		
	EndIf;
	
EndFunction

Function GenerateAddressByPresentation(Presentation, SplitByFields = False, ToStructure = False)
	
	HasAddressManagerClientServer = Metadata.CommonModules.Find("AddressManagerClientServer") <> Undefined;
	
	If HasAddressManagerClientServer Then
		ModuleAddressManagerClientServer = Common.CommonModule("AddressManagerClientServer");
		Address = ModuleAddressManagerClientServer.NewContactInformationDetails(Enums.ContactInformationTypes.Address);
		DescriptionMainCountry = TrimAll(ModuleAddressManagerClientServer.MainCountry().Description);
	Else
		Address = ContactsManagerClientServer.NewContactInformationDetails(Enums.ContactInformationTypes.Address);
		DescriptionMainCountry = "";
	EndIf;
	
	// Parsing the address presentation by classifier.
	If Not Common.SubsystemExists("StandardSubsystems.AddressClassifier") Then
		Address.Value = Presentation;
		Return Address;
	EndIf;
	
	AnalysisData = AddressPartsAsTable(Presentation);
	If AnalysisData.Count() = 0 Then
		Return Address;
	EndIf;
	
	DefineCountryAndZipCode(AnalysisData);
	CountryString = AnalysisData.Find(-2, "Level");
	
	If CountryString = Undefined Then
		Address.Country = DescriptionMainCountry;
	Else
		Address.Country = TrimAll(Upper(CountryString.Value));
		// Checking if there is a country in the World country catalog and implicitly adding it in case of absence.
		WorldCountry = ContactsManager.WorldCountryByCodeOrDescription(Address.Country);
	EndIf;
	
	// Processing common short forms in the address.
	ProcessingCommonShortFormInAddresses(AnalysisData);
	
	If Address.Country = DescriptionMainCountry Then
		
		If Common.SubsystemExists("StandardSubsystems.AddressClassifier") Then
			
			ModuleAddressClassifierInternal = Common.CommonModule("AddressClassifierInternal");
			AddressOptions = ModuleAddressClassifierInternal.IdentifyAddress(AnalysisData, Presentation, ToStructure);
			
			If AddressOptions = Undefined Then
				
				If SplitByFields Then
					
					ModuleAddressManagerClientServer = Common.CommonModule("AddressManagerClientServer");
					Address.AddressType = ModuleAddressManagerClientServer.MunicipalAddress();
					
					Address.Value = Presentation;
					DistributeAddressToFieldsWithoutClassifier(Address, AnalysisData);
					
				Else
					
					Address.Value = Presentation;
					Address.AddressType = ContactsManagerClientServer.AddressInFreeForm();
					
				EndIf;
			Else
				
				Address = AddressOptions;
				If HasAddressManagerClientServer Then
					ModuleAddressManagerClientServer = Common.CommonModule("AddressManagerClientServer");
					ModuleAddressManagerClientServer.UpdateAddressPresentation(Address, False);
				Else
					ContactsManagerClientServer.UpdateAddressPresentation(Address, False);
				EndIf;
				
			EndIf;
			
		EndIf;
		
	Else
		
		If HasAddressManagerClientServer Then
			ModuleAddressManagerClientServer = Common.CommonModule("AddressManagerClientServer");
			AddressType = ?(ContactsManager.IsEEUMemberCountry(Address.Country),
				ContactsManagerClientServer.EEUAddress(),
				ContactsManagerClientServer.ForeignAddress());
			Address.AddressType = AddressType;
		Else
			Address.AddressType = ContactsManagerClientServer.AddressInFreeForm();
		EndIf;
		
		NewPresentation = New Array;
		AnalysisData.Sort("Position");
		For each AddressPart In AnalysisData Do
			If AddressPart.Level >=0 Then
				NewPresentation.Add(AddressPart.Value);
			EndIf;
		EndDo;
		
		Address.Area = StrConcat(NewPresentation, ", ");
		
	EndIf;
	
	If IsBlankString(Address.ZipCode) Then
		StringIndex = AnalysisData.Find(-1, "Level");
		If StringIndex <> Undefined Then
			Address.ZipCode = TrimAll(StringIndex.Value);
		EndIf;
	EndIf;
	
	Return Address;
	
EndFunction

Procedure ProcessingCommonShortFormInAddresses(Val AnalysisData)
	
	USTerritorialEntitiy = New Map();
	USTerritorialEntitiy.Insert(NStr("ru='САНКТ-ПЕТЕРБУРГ'; en = 'SAINT PETERSBURG'; pl = 'SANKT PETERSBURG';es_ES = 'SAN PETERSBURGO';es_CO = 'SAN PETERSBURGO';tr = 'SAINT PETERSBURG';it = 'SAN PIETROBURGO';de = 'SANKT-PETERSBURG'"), "St.-Petersburg");
	USTerritorialEntitiy.Insert(NStr("ru='МОСКВА'; en = 'MOSCOW'; pl = 'MOSKWA';es_ES = 'MOSCÚ';es_CO = 'MOSCÚ';tr = 'MOSKOVA';it = 'MOSCOW';de = 'MOSKAU'"), "Moscow");
	USTerritorialEntitiy.Insert(NStr("ru='МСК'; en = 'MSK'; pl = 'MSK';es_ES = 'MSK';es_CO = 'MSK';tr = 'MSK';it = 'MSK';de = 'MSK'"), "Moscow");
	USTerritorialEntitiy.Insert(NStr("ru='СПБ'; en = 'SPB'; pl = 'SPB';es_ES = 'SPB';es_CO = 'SPB';tr = 'SPB';it = 'SPB';de = 'SPB'"), "St.-Petersburg");
	
	For each AddressPart In AnalysisData Do
		Description = Upper(AddressPart.Description);
		If USTerritorialEntitiy.Get(Description ) <> Undefined AND IsBlankString(AddressPart.ShortForm) Then
			AddressPart.Description = USTerritorialEntitiy.Get(Description );
			AddressPart.ShortForm = "city";
		EndIf;
	EndDo;

EndProcedure

Procedure DistributeAddressToFieldsWithoutClassifier(Address, AnalysisData)
	
	PresentationByAnalysisData = New Array;
	For each AddressPart In AnalysisData Do
		If AddressPart.Level >= 0 Then
			PresentationByAnalysisData.Add(TrimAll(AddressPart.Description + " " + AddressPart.ShortForm));
		EndIf;
	EndDo;
	
	Address.Street = StrConcat(PresentationByAnalysisData, ", ");
	
EndProcedure

Function AddressPartsAsTable(Val Text)
	
	StringType = New TypeDescription("String", New StringQualifiers(128));
	NumberType  = New TypeDescription("Number");
	
	Result = New ValueTable;
	Columns = Result.Columns;
	Columns.Add("Level", NumberType);
	Columns.Add("Position", NumberType);
	Columns.Add("Value", StringType);
	Columns.Add("Description", StringType);
	Columns.Add("ShortForm", StringType);
	Columns.Add("Begin", NumberType);
	Columns.Add("Length", NumberType);
	Columns.Add("ID", StringType);
	
	Number = 1;
	For Each Term In TextWordsAsTable(Text, "," + Chars.LF) Do
		Value = TrimAll(Term.Value);
		If IsBlankString(Value) Then
			Continue;
		EndIf;
		
		Row = Result.Add();
		
		Row.Level = 0;
		Row.Position  = Number;
		Number = Number + 1;
		
		Row.Begin = Term.Begin;
		Row.Length  = Term.Length;
		
		Position = StrLen(Value);
		While Position > 0 Do
			Char = Mid(Value, Position, 1);
			If IsBlankString(Char) Then
				Row.Description = TrimAll(Left(Value, Position-1));
				Break;
			EndIf;
			Row.ShortForm = Char + Row.ShortForm;
			Position = Position - 1;
		EndDo;
		
		If IsBlankString(Row.Description) Then
			Row.Description = TrimAll(Row.ShortForm);
			Row.ShortForm   = "";
		EndIf;
		Row.Value = TrimAll(Row.Description + " " + Row.ShortForm);
	EndDo;
	
	Return Result;
EndFunction

Function TextWordsAsTable(Val Text, Val Separators = Undefined)
	
	// Deleting special characters (dots, numbers) from the text.
	Text = StrReplace(Text, "№", "");
	
	WordBeginning = 0;
	State   = 0;
	
	StringType = New TypeDescription("String");
	NumberType  = New TypeDescription("Number");
	
	Result = New ValueTable;
	Columns = Result.Columns;
	Columns.Add("Value", StringType);
	Columns.Add("Begin",   NumberType);
	Columns.Add("Length",    NumberType);
	
	For Position = 1 To StrLen(Text) Do
		CurrentChar = Mid(Text, Position, 1);
		IsSeparator = ?(Separators = Undefined, IsBlankString(CurrentChar), StrFind(Separators, CurrentChar) > 0);
		
		If State = 0 AND (Not IsSeparator) Then
			WordBeginning = Position;
			State   = 1;
		ElsIf State = 1 AND IsSeparator Then
			Row = Result.Add();
			Row.Begin = WordBeginning;
			Row.Length  = Position-WordBeginning;
			Row.Value = Mid(Text, Row.Begin, Row.Length);
			State = 0;
		EndIf;
	EndDo;
	
	If State = 1 Then
		Row = Result.Add();
		Row.Begin = WordBeginning;
		Row.Length  = Position-WordBeginning;
		Row.Value = Mid(Text, Row.Begin, Row.Length)
	EndIf;
	
	Return Result;
EndFunction

Procedure DefineCountryAndZipCode(AddressData)
	
	TypeDescriptionNumber = New TypeDescription("Number");
	
	Classifier = ContactsManager.ClassifierTable();
	For each AddressItem In AddressData Do
		Index = TypeDescriptionNumber.AdjustValue(AddressItem.Description);
		If Index >= 100000 AND Index < 1000000 Then
			AddressItem.Level = -1;
		Else
			If Classifier.Find(Upper(AddressItem.Value), "Description") <> Undefined Then
				AddressItem.Level = -2;
			EndIf;
		EndIf;
	EndDo;
	
EndProcedure

// Parses a CI presentation and returns XDTO.
//
//  Parameters:
//      Text - String - XML
//      ExpectedKind - CatalogRef.ContactsKinds, EnumRef.ContactsTypes, Structure.
//
// Returns:
//      XDTOObject - contact information.
//
Function XDTOContactsByPresentation(Text, ExpectedKind) Export
	
	ExpectedType = ContactInformationManagementInternalCached.ContactInformationKindType(ExpectedKind);
	
	If ExpectedType = Enums.ContactInformationTypes.Address Then
		Return XMLAddressInXDTO("", Text, ExpectedType);
		
	ElsIf ExpectedType = Enums.ContactInformationTypes.EmailAddress Then
		Return OtherContactInformationDeserialization("", Text, ExpectedType);
		
	ElsIf ExpectedType = Enums.ContactInformationTypes.WebPage Then
		Return OtherContactInformationDeserialization("", Text, ExpectedType);
		
	ElsIf ExpectedType = Enums.ContactInformationTypes.Phone Then
		Return PhoneDeserialization("", Text, ExpectedType);
		
	ElsIf ExpectedType = Enums.ContactInformationTypes.Fax Then
		Return FaxDeserialization("", Text, ExpectedType);
		
	ElsIf ExpectedType = Enums.ContactInformationTypes.Skype Then
		Return OtherContactInformationDeserialization("", Text, ExpectedType);
		
	ElsIf ExpectedType = Enums.ContactInformationTypes.Other Then
		Return OtherContactInformationDeserialization("", Text, ExpectedType);
		
	EndIf;
	
	Return Undefined;
EndFunction

// Converts a string into XDTO contact information of address.
//
//  Parameters:
//      FieldsValues - String - serialized information, field values.
//      Presentation - String - superiority-based presentation. Used for parsing purposes if 
//                               FieldsValues is empty.
//      ExpectedType - EnumRef.ContactsType - an optional type for control.
//
//  Returns:
//      XDTOObject - contact information.
//
Function XMLAddressInXDTO(Val FieldsValues, Val Presentation = "", Val ExpectedType = Undefined) Export
	
	If Metadata.DataProcessors.Find("AdvancedContactInformationInput") <> Undefined Then
		Return DataProcessors["AdvancedContactInformationInput"].XMLAddressInXDTO(FieldsValues, Presentation, ExpectedType);
	EndIf;
	
	// Empty object with presentation.
	Namespace = ContactsManagerClientServer.Namespace();
	Result = XDTOFactory.Create(XDTOFactory.Type(Namespace, "ContactInformation"));
	Result.Content = XDTOFactory.Create(XDTOFactory.Type(Namespace, "Address"));
	Result.Content.Content = Presentation;
	Result.Presentation = Presentation;
	Return Result;
	
EndFunction

// Converts a string into XDTO contact information of phone.
//
//      FieldsValues - String - serialized information, field values.
//      Presentation - String - superiority-based presentation. Used for parsing purposes if 
//                               FieldsValues is empty.
//      ExpectedType - EnumRef.ContactsType - an optional type for control.
//
//  Returns:
//      XDTOObject - contact information.
//
Function PhoneDeserialization(FieldsValues, Presentation = "", ExpectedType = Undefined) Export
	Return PhoneFaxDeserialization(FieldsValues, Presentation, ExpectedType);
EndFunction

// Converts a string into XDTO contact information of fax.
//
//      FieldsValues - String - serialized information, field values.
//      Presentation - String - superiority-based presentation. Used for parsing purposes if 
//                               FieldsValues is empty.
//      ExpectedType - EnumRef.ContactsType - an optional type for control.
//
//  Returns:
//      XDTOObject - contact information.
//
Function FaxDeserialization(FieldsValues, Presentation = "", ExpectedType = Undefined) Export
	Return PhoneFaxDeserialization(FieldsValues, Presentation, ExpectedType);
EndFunction

// Converts a string into other XDTO contact information.
//
// Parameters:
//   FieldsValues - String - serialized information, field values.
//   Presentation - String - superiority-based presentation. Used for parsing purposes if FieldsValues is empty.
//   ExpectedType - EnumRef.ContactsType - an optional type for control.
//
// Returns:
//   XDTOObject - contact information.
//
Function OtherContactInformationDeserialization(FieldsValues, Presentation = "", ExpectedType = Undefined)
	
	If ContactsManagerClientServer.IsXMLContactInformation(FieldsValues) Then
		// Common format of contact information.
		Return ContactsFromXML(FieldsValues, ExpectedType);
	EndIf;
	
	Namespace = ContactsManagerClientServer.Namespace();
	Result = XDTOFactory.Create(XDTOFactory.Type(Namespace, "ContactInformation"));
	Result.Presentation = Presentation;
	
	If ExpectedType = Enums.ContactInformationTypes.EmailAddress Then
		Result.Content = XDTOFactory.Create(XDTOFactory.Type(Namespace, "Email"));
		
	ElsIf ExpectedType = Enums.ContactInformationTypes.WebPage Then
		Result.Content = XDTOFactory.Create(XDTOFactory.Type(Namespace, "Website"));
		
	ElsIf ExpectedType = Enums.ContactInformationTypes.Skype Then
		Result.Content = XDTOFactory.Create(XDTOFactory.Type(Namespace, "Skype"));
		
	ElsIf ExpectedType = Enums.ContactInformationTypes.Other Then
		Result.Content = XDTOFactory.Create(XDTOFactory.Type(Namespace, "Other"));
		
	ElsIf ExpectedType <> Undefined Then
		Raise NStr("ru = 'Ошибка десериализации контактной информации, ожидается другой тип'; en = 'Contact information deserialization error. Another type is expected.'; pl = 'Wystąpił błąd podczas deserializowania informacji kontaktowych, oczekiwany jest inny typ';es_ES = 'Ha ocurrido un error al deserializar la información de contacto, otro tipo está esperado';es_CO = 'Ha ocurrido un error al deserializar la información de contacto, otro tipo está esperado';tr = 'İletişim bilgilerinin seriden paralele çevrilmesi sırasında bir hata oluştu, diğer tür bekleniyor';it = 'Errore della deserializzazione delle informazioni di contatto. Un altro tipo è atteso.';de = 'Beim Deserialisieren der Kontaktinformationen ist ein Fehler aufgetreten, ein anderer Typ wird erwartet'");
		
	EndIf;
	
	Result.Content.Value = Presentation;
	
	Return Result;
	
EndFunction

// Returns contact information presentation.
//
// Parameters:
//   ContactInformation -String - an address in a JSON or XML format.
//   ContactInformationFormat  - String             - if set to "ARCA", the address presentation 
//                                        does not include values of county and city district levels.
//    ContactsType - Structure - additional parameters of presentation generation for the addresses:
//      * Type - String - a contact information type.
//      * IncludeCountryInPresentation - Boolean - an address country will be included in the presentation;
//      * AddressFormat                 - String - if set to "ARCA", the address presentation does 
//                                                not include values of county and city district levels.
// Returns:
//      String - a generated presentation.
//
Function ContactInformationPresentation(Val ContactInformation, Val ContactsFormat) Export
	
	If IsBlankString(ContactInformation) Then
		Return "";
	EndIf;
	
	Kind = Undefined;
	If ContactsManagerClientServer.IsJSONContactInformation(ContactInformation) Then
		ContactInformation = JSONStringToStructure(ContactInformation);
	ElsIf TypeOf(ContactInformation) = Type("String") Or TypeOf(ContactInformation) = Type("XDTODataObject") Then
		ContactInformation = ContactInformationToJSONStructure(ContactInformation);
	EndIf;
	If IsBlankString(ContactInformation.Value) Then
		GenerateContactInformationPresentation(ContactInformation, Kind);
	EndIf;
	
	Return ContactInformation.Value
	
EndFunction

// Evaluates that the address was entered in free format.
//
//  Parameters:
//      ContactInformation - Structure, String - contact information.
//
//  Returns:
//      Boolean - a new value.
//
Function AddressEnteredInFreeFormat(Val ContactInformation) Export
	
	If ContactsManagerClientServer.IsXMLContactInformation(ContactInformation) Then
		JSONContacts = ContactsManager.ContactInformationInJSON(ContactInformation);
		ContactInformation = JSONStringToStructure(JSONContacts);
	ElsIf ContactsManagerClientServer.IsJSONContactInformation(ContactInformation) Then
		ContactInformation = JSONStringToStructure(ContactInformation);
	EndIf;
	
	If TypeOf(ContactInformation) = Type("Structure")
		AND ContactInformation.Property("AddressType") Then
			Return ContactsManagerClientServer.IsAddressInFreeForm(ContactInformation.AddressType);
	EndIf;
	
	Return False;
	
EndFunction

// Generates and returns contact information presentation.
//
// Parameters:
//   Information - Structure, String - contact information in a JSON format or a structure with fields.
//   InfomationKind - CatalogRef.ContactsKinds, Structure - parameters for presentation generation.
//
// Returns:
//      String - a generated presentation.
//
Function GenerateContactInformationPresentation(Val Information, Val InformationKind)
	
	If TypeOf(Information) = Type("String") AND ContactsManagerClientServer.IsJSONContactInformation(Information) Then
		Information = JSONStringToStructure(Information);
	EndIf;
	
	If TypeOf(Information) = Type("Structure") Then
		
		If ContactsManagerClientServer.IsAddressType(Information.Type) Then
			Return AddressPresentation(Information, InformationKind);
			
		ElsIf Information.Type = String(Enums.ContactInformationTypes.Phone)
			OR Information.Type = String(Enums.ContactInformationTypes.Fax) Then
			PhonePresentation = PhonePresentation(Information);
			Return ?(IsBlankString(PhonePresentation), Information.Value, PhonePresentation);
		EndIf;
		
		Return Information.Value;
	EndIf;
	
	// Old format or a new deserialized format.
	Return GenerateContactInformationPresentation(ContactInformationToJSONStructure(Information), InformationKind);
	
EndFunction

// Returns the flag specifying whether the passed address is local.
//
//  Parameters:
//      Address - Structure, String - address contact information as a structure or a JSON string.
//
//  Returns:
//      Boolean - the result of the check.
//
Function IsNationalAddress(Val Address) Export
	
	If NOT ValueIsFilled(Address) Then
		Return False;
	EndIf;
	
	If Metadata.CommonModules.Find("AddressManagerClientServer") <> Undefined Then
		
		If TypeOf(Address) = Type("String") Then
			Address = JSONStringToStructure(Address);
		EndIf;
		
		If TypeOf(Address) = Type("Structure") AND Address.Property("Country")Then
			
			ModuleAddressManagerClientServer = Common.CommonModule("AddressManagerClientServer");
			CountryDescription = Common.ObjectAttributeValue(ModuleAddressManagerClientServer.MainCountry(), "Description");
			Return StrCompare(CountryDescription, Address.Country) = 0;
			
		EndIf;
		
	EndIf;
	
	Return False;
	
EndFunction

// Generates an address presentation according to the rule:
//  1) Country, if necessary.
//  2) Postal code, territorial entity, county, district, city, city district, locality, and street.
//  3) Buildings, premises.
//
// Parameters:
//  Address			 - Structure - an address broken down by fields.
//  ContactsKind	 - Structure - details of a contacts kind.
// 
// Returns:
//  String - an address presentation.
//
Function AddressPresentation(Val Address, Val InformationKind)
	
	If TypeOf(InformationKind) = Type("Structure") AND InformationKind.Property("IncludeCountryInPresentation") Then
		IncludeCountryInPresentation = InformationKind.IncludeCountryInPresentation;
	Else
		IncludeCountryInPresentation = False;
	EndIf;
	
	If TypeOf(Address) = Type("Structure") Then
		
		If Metadata.CommonModules.Find("AddressManagerClientServer") <> Undefined Then
			ModuleAddressManagerClientServer = Common.CommonModule("AddressManagerClientServer");
			ModuleAddressManagerClientServer.UpdateAddressPresentation(Address, IncludeCountryInPresentation);
		Else
			ContactsManagerClientServer.UpdateAddressPresentation(Address, IncludeCountryInPresentation);
		EndIf;
		
		Return Address.Value;
	Else
		// This is a foreign address
		Presentation = TrimAll(Address);
		
		If StrOccurrenceCount(Presentation, ",") = 9 Then
			// Deleting empty values and a country.
			PresentationAsArray = StrSplit(Presentation, ",", False);
			If PresentationAsArray.Count() > 0 Then
				For Index = 0 To PresentationAsArray.UBound() Do
					PresentationAsArray[Index] = TrimAll(PresentationAsArray[Index]);
				EndDo;
				PresentationAsArray.Delete(0); // Deleting a country
				Presentation = StrConcat(PresentationAsArray, ", ");
			EndIf;
		EndIf;
	EndIf;
	
	Return Presentation;
	
EndFunction

Function PhonePresentation(PhoneData)
	
	If TypeOf(PhoneData) = Type("Structure") Then
		
		PhonePresentation = ContactsManagerClientServer.GeneratePhonePresentation(
			RemoveNonDigitCharacters(PhoneData.countryCode),
			PhoneData.areaCode,
			PhoneData.number,
			PhoneData.extNumber,
			"");
			
	Else
		
		PhonePresentation = ContactsManagerClientServer.GeneratePhonePresentation(
			RemoveNonDigitCharacters(PhoneData.CountryCode), 
			PhoneData.CityCode,
			PhoneData.Number,
			PhoneData.Extension,
			"");
		
	EndIf;
	
	Return PhonePresentation;
	
EndFunction

// Constructor of a structure compatible by fields with the contact information kinds catalog.
//
// Parameters:
//     Source - CatalogRef.ContactsKinds - an optional source of data to be filled.
//
// Returns:
//     Structure - compatible by fields with the contact information kinds catalog.
//
Function ContactInformationKindStructure(Val Source = Undefined) Export
	
	AttributesMetadata = Metadata.Catalogs.ContactInformationKinds.Attributes;
	
	If TypeOf(Source) = Type("CatalogRef.ContactInformationKinds") Then
		Attributes = "Description";
		For Each AttributeMetadata In AttributesMetadata Do
			Attributes = Attributes + "," + AttributeMetadata.Name;
		EndDo;
		
		Result = Common.ObjectAttributesValues(Source, Attributes);
	Else
		Result = New Structure("Description", "");
		For Each AttributeMetadata In AttributesMetadata Do
			Result.Insert(AttributeMetadata.Name, AttributeMetadata.Type.AdjustValue());
		EndDo;
		If Source <> Undefined Then
			FillPropertyValues(Result, Source);
		EndIf;
	EndIf;
	Result.Insert("Ref", Source);
	
	Return Result;
	
EndFunction

Function ContactsKindsData(Val ContactInformationKinds) Export
	
	AttributesMetadata = Metadata.Catalogs.ContactInformationKinds.Attributes;
	Attributes = "Description, PredefinedDataName, DeletionMark";
	For Each AttributeMetadata In AttributesMetadata Do
		Attributes = Attributes + "," + AttributeMetadata.Name;
	EndDo;
	
	Return Common.ObjectsAttributesValues(ContactInformationKinds, Attributes);
	
EndFunction

// Updates aggregated field KindForList of the object contact information.
//
// Parameters:
//  Object - CatalogObject - an object with the ContactInformation tabular section.
//
Procedure UpdateCotactsForListsForObject(Object) Export
	
	ContactInformation = Object.ContactInformation;
	
	If ContactInformation.Count() = 0 Then
		Return;
	EndIf;
	
	Index = ContactInformation.Count() - 1;
	While Index >= 0 Do
		If NOT ValueIsFilled(ContactInformation[Index].Kind) Then
			ContactInformation.Delete(Index);
		EndIf;
		Index = Index -1;
	EndDo;
	
	ColumnValidFromMissing = (Object.Metadata().TabularSections.ContactInformation.Attributes.Find("ValidFrom") = Undefined);
	
	Query = New Query("SELECT
		|	ContactInformation.Presentation AS Presentation,
		|	ContactInformation.Kind AS Kind" + ?(ColumnValidFromMissing, "", ", ContactInformation.ValidFrom AS ValidFrom") + "
		|INTO ContactInformation
		|FROM
		|	&ContactInformation AS ContactInformation
		|;");
	
	If ColumnValidFromMissing Then
		Query.Text = Query.Text + "SELECT
		|	ContactInformation.Presentation AS Presentation,
		|	ContactInformation.Kind AS Kind,
		|	COUNT(ContactInformation.Kind) AS Count
		|FROM
		|	ContactInformation AS ContactInformation
		|
		|GROUP BY
		|	ContactInformation.Kind,
		|	ContactInformation.Presentation TOTALS BY Kind";
	Else
		Query.Text = Query.Text + "SELECT
		|	ContactInformation.Kind AS Kind,
		|	MAX(ContactInformation.ValidFrom) AS ValidFrom
		|INTO LatestContactInformation
		|FROM
		|	ContactInformation AS ContactInformation
		|
		|GROUP BY
		|	ContactInformation.Kind
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT
		|	ContactInformation.Presentation AS Presentation,
		|	ContactInformation.Kind AS Kind,
		|	ContactInformation.ValidFrom AS ValidFrom,
		|	COUNT(ContactInformation.Kind) AS Count
		|FROM
		|	LatestContactInformation AS LatestContactInformation
		|		LEFT JOIN ContactInformation AS ContactInformation
		|		ON LatestContactInformation.ValidFrom = ContactInformation.ValidFrom
		|			AND LatestContactInformation.Kind = ContactInformation.Kind
		|
		|GROUP BY
		|	ContactInformation.Kind,
		|	ContactInformation.Presentation,
		| ContactInformation.ValidFrom
		|TOTALS BY
		|	Kind, ValidFrom"; 
	EndIf;
	
	Query.SetParameter("ContactInformation", ContactInformation);
	QueryResult = Query.Execute();
	SelectionKind       = QueryResult.Select(QueryResultIteration.ByGroups);
	
	While SelectionKind.Next() Do
		DetailedRecordsSelection = SelectionKind.Select();
		If SelectionKind.Count = 1 Then
			If ColumnValidFromMissing Then
				TablesRow = ContactInformation.Find(SelectionKind.Kind, "Kind");
				TablesRow.KindForList = SelectionKind.Kind;
			Else
				ValidFrom = Date(1,1,1);
				While DetailedRecordsSelection.Next() Do
					If ValueIsFilled(DetailedRecordsSelection.ValidFrom) Then
						ValidFrom = DetailedRecordsSelection.ValidFrom;
					EndIf;
				EndDo;
				FoundRows = ContactInformation.FindRows(New Structure("Kind", SelectionKind.Kind));
				For each RowWithContacts In FoundRows Do
					RowWithContacts.KindForList = ?(RowWithContacts.ValidFrom = ValidFrom,
							SelectionKind.Kind, Catalogs.ContactInformationKinds.EmptyRef());
				EndDo;
			EndIf;
		ElsIf SelectionKind.Count > 1 Then
			ContactsItems = New Array;
			While DetailedRecordsSelection.Next() Do
				If ValueIsFilled(DetailedRecordsSelection.Presentation) Then
					ContactsItems.Add(DetailedRecordsSelection.Presentation);
				EndIf;
			EndDo;
			TablesRow               = ContactInformation.Add();
			TablesRow.KindForList  = SelectionKind.Kind;
			TablesRow.Presentation = StrConcat(ContactsItems, ", ");
		EndIf;
	EndDo;
	
EndProcedure

// Updates aggregated field KindForList in the ContactInformation tabular sections of all objects.
//
Procedure UpdateContactInformationForLists() Export
	
	ObjectsWithKindForListColumn = ObjectsContainingKindForList();
	
	For each ObjectRef In ObjectsWithKindForListColumn Do
		Object = ObjectRef.GetObject();
		ContactInformation = Object.ContactInformation;
		
		Filter = New Structure("Type", Enums.ContactInformationTypes.EmptyRef());
		RowsForDeletion = ContactInformation.FindRows(Filter);
		For each RowForDeletion In RowsForDeletion Do
			ContactInformation.Delete(RowForDeletion);
		EndDo;
		
		Query = New Query;
		Query.Text = 
			"SELECT
			|	ContactInformation.Presentation AS Presentation,
			|	ContactInformation.Kind AS Kind
			|INTO ContactInformation
			|FROM
			|	&ContactInformation AS ContactInformation
			|;
			|
			|////////////////////////////////////////////////////////////////////////////////
			|SELECT
			|	ContactInformation.Presentation AS Presentation,
			|	ContactInformation.Kind AS Kind,
			|	COUNT(ContactInformation.Kind) AS Count
			|FROM
			|	ContactInformation AS ContactInformation
			|
			|GROUP BY
			|	ContactInformation.Kind,
			|	ContactInformation.Presentation TOTALS BY Kind";
		
		Query.SetParameter("ContactInformation", ContactInformation);
		QueryResult = Query.Execute();
		SelectionKind = QueryResult.Select(QueryResultIteration.ByGroups);
		
		While SelectionKind.Next() Do
			DetailedRecordsSelection = SelectionKind.Select();
			If SelectionKind.Count = 1 Then
				TablesRow = ContactInformation.Find(SelectionKind.Kind, "Kind");
				TablesRow.KindForList = SelectionKind.Kind;
			ElsIf SelectionKind.Count > 1 Then
				TablesRow = ContactInformation.Add();
				TablesRow.KindForList = SelectionKind.Kind;
				Separator = "";
				Presentation = "";
				While DetailedRecordsSelection.Next() Do
					Presentation = Presentation +Separator + DetailedRecordsSelection.Presentation;
					Separator = ", ";
				EndDo;
				TablesRow.Presentation = Presentation;
			EndIf;
		EndDo;
		InfobaseUpdate.WriteData(Object);
	EndDo;

EndProcedure

Function ObjectsContainingKindForList()
	
	MetadataObjects = New Array;
	Query = New Query;
	Query.Text = 
	"SELECT
	|	ContactInformationKinds.Ref,
	|	ContactInformationKinds.PredefinedDataName
	|FROM
	|	Catalog.ContactInformationKinds AS ContactInformationKinds
	|WHERE
	|	ContactInformationKinds.IsFolder = TRUE";
	
	QueryResult = Query.Execute();
	DetailedRecordsSelection = QueryResult.Select();
	While DetailedRecordsSelection.Next() Do
		If StrStartsWith(DetailedRecordsSelection.PredefinedDataName, "Catalog") Then
			ObjectName = Mid(DetailedRecordsSelection.PredefinedDataName, 11);
			If Metadata.Catalogs.Find(ObjectName) <> Undefined Then 
				ContactInformation = Metadata.Catalogs[ObjectName].TabularSections.ContactInformation;
				If ContactInformation.Attributes.Find("KindForList") <> Undefined Then
					MetadataObjects.Add(Catalogs[ObjectName].EmptyRef());
				EndIf;
			EndIf;
		ElsIf StrStartsWith(DetailedRecordsSelection.PredefinedDataName, "Document") Then
			ObjectName = Mid(DetailedRecordsSelection.PredefinedDataName, 9);
			If Metadata.Documents.Find(ObjectName) <> Undefined Then
				ContactInformation = Metadata.Documents[ObjectName].TabularSections.ContactInformation;
				If ContactInformation.Attributes.Find("KindForList") <> Undefined Then
					MetadataObjects.Add(Documents[ObjectName].EmptyRef());
				EndIf;
			EndIf;
		EndIf;
	EndDo;
	
	Separator = "";
	QueryText = "";
	For each Object In MetadataObjects Do
		QueryText = QueryText + Separator + " SELECT
		|	ContactInformation.Ref AS Ref
		|FROM
		|	Catalog." + Object.Metadata().Name + ".ContactInformation AS ContactInformation
		|WHERE
		|	ContactInformation.Kind <> VALUE(Catalog.ContactInformationKinds.EmptyRef)
		|
		|GROUP BY
		|	ContactInformation.Ref
		|
		|HAVING
		|	COUNT(ContactInformation.Kind) > 0 ";
		Separator = " UNION ALL ";
	EndDo;
	
	Query = New Query(QueryText);
	QueryResult = Query.Execute().Unload().UnloadColumn("Ref");

	Return QueryResult;

EndFunction

// Checks whether the parameters of contact information kind are correct.
//
// Parameters:
//  ContactsKind - CatalogRef.ContactsKinds - a kind of contacts to be validated.
//
// Returns:
//  Structure - a result of contact information kind check.
//   * HasErrors - Boolean - indicates whether there are errors in the contact information kind.
//   * ErrorText - String - error information.
Function CheckContactsKindParameters(ContactInformationKind) Export
	
	Result = New Structure("HasErrors, ErrorText", False, "");
	
	If NOT ValueIsFilled(ContactInformationKind.Type) Then
		Result.HasErrors = True;
		Result.ErrorText = StringFunctionsClientServer.SubstituteParametersToString(NStr("ru = 'Не заполонено обязательное поле тип у типа контактной информации ""%1"".'; en = 'Type field is required for contact information kind ""%1"".'; pl = 'Nie jest wypełnione wymagane pole rodzaj u rodzaju informacji kontaktowych ""%1"".';es_ES = 'No está rellenado el campo obligatorio tipo de la información de contacto ""%1"".';es_CO = 'No está rellenado el campo obligatorio tipo de la información de contacto ""%1"".';tr = 'İletişim bilgileri türündeki zorunlu tip ""%1"" alanı doldurulmamıştır.';it = 'Il tipo di file è richiesto per la tipologia informazione di contatto ""%1"".';de = 'Das erforderliche Feld für die Art der Kontaktinformationen ""%1"" ist nicht ausgefüllt.'"),
			String(ContactInformationKind.Description));
		Return Result;
	EndIf;
	
	Separator = "";
	If ContactInformationKind.Type = Enums.ContactInformationTypes.Address Then
		
		If NOT ContactInformationKind.OnlyNationalAddress
			AND (ContactInformationKind.CheckValidity
			OR ContactInformationKind.HideObsoleteAddresses) Then
				Result.ErrorText = StringFunctionsClientServer.SubstituteParametersToString(NStr("ru = 'Некорректно заполнены настройки проверки адреса у вида контактной информации %1.
					| Проверка корректности адреса доступна только для российских адресов'; 
					|en = 'Incorrect address check settings for contact information kind %1.
					|Checking is only available for Russian addresses'; 
					|pl = 'Są niepoprawnie wypełnione ustawienia weryfikacji adresu u rodzaju informacji kontaktowych %1.
					| Weryfikacja poprawności adresów jest dostępna tylko dla rosyjskich adresów';
					|es_ES = 'Los ajustes de comprobar la dirección del tipo de la información de contacto están rellenados incorrectamente %1.
					| Comprobar la corrección de la dirección se puede solo para as direcciones rusas';
					|es_CO = 'Los ajustes de comprobar la dirección del tipo de la información de contacto están rellenados incorrectamente %1.
					| Comprobar la corrección de la dirección se puede solo para as direcciones rusas';
					|tr = 'İletişim bilgileri görünümünde adres doğrulama ayarları yanlış dolduruldu%1 . 
					|Adres doğruluğu doğrulama sadece Rus adresleri için kullanılabilir';
					|it = 'Impostazioni di verifica indirizzo errate per il tipo di informazione di contatto %1.
					|Solo gli indirizzi russi possono effettuare la verifica';
					|de = 'Die Einstellungen zur Adressverifizierung für den Kontaktinformationstyp sind falsch ausgefüllt %1.
					|Die Adressverifizierung ist nur für russische Adressen verfügbar'"), String(ContactInformationKind.Description));
					Separator = Chars.LF;
			EndIf;
			
		If ContactInformationKind.AllowMultipleValueInput
			AND ContactInformationKind.StoreChangeHistory Then
				Result.ErrorText = Result.ErrorText + Separator + StringFunctionsClientServer.SubstituteParametersToString(NStr("ru = 'Некорректно заполнены настройки адреса у вида контактной информации %1.
					| Не допускается возможность ввода нескольких значений контактной информации при включенной истории хранения изменений.'; 
					|en = 'Incorrect address settings for contact information kind %1.
					| Multiple values for contact information are not allowed if changes history is enabled.'; 
					|pl = 'Są niepoprawnie wypełnione ustawienia adresu u rodzaju informacji kontaktowych %1.
					| Nie dopuszcza się możliwość wprowadzania wielu wartości informacji kontaktowych przy włączonej historii przechowywania zmian.';
					|es_ES = 'Los ajustes de la dirección del tipo de la información de contacto están rellenados incorrectamente %1.
					| No se admite introducir unos valores de la información de contacto si el historial del guardar los cambios está activado.';
					|es_CO = 'Los ajustes de la dirección del tipo de la información de contacto están rellenados incorrectamente %1.
					| No se admite introducir unos valores de la información de contacto si el historial del guardar los cambios está activado.';
					|tr = 'İletişim bilgileri görünümünde adres ayarları yanlış dolduruldu%1 .
					| Değişiklik depolama geçmişi etkin olduğunda birden çok iletişim bilgileri değerleri girmek için izin verilmez.';
					|it = 'Impostazioni di indirizzo errate per il tipo di informazione di contatto %1.
					|Non sono permessi valori multipli per le informazioni di contatto se è attivata la modifica alla cronologia.';
					|de = 'Die Adresseinstellungen für den Kontaktinformationstyp sind falsch ausgefüllt %1.
					|Es ist nicht erlaubt, mehrere Werte von Kontaktinformationen einzugeben, wenn der Verlauf der Änderungen im Speicher aktiviert ist.'"),
						String(ContactInformationKind.Description));
		EndIf;
	EndIf;
	
	Result.HasErrors = ValueIsFilled(Result.ErrorText);
	Return Result;
	
EndFunction

Function PhoneNumberToOldFieldList(XDTOPhone) Export
	Result = New ValueList;
	
	Result.Add(XDTOPhone.CountryCode,  "CountryCode");
	Result.Add(XDTOPhone.CityCode,  "CityCode");
	Result.Add(XDTOPhone.Number,      "PhoneNumber");
	Result.Add(XDTOPhone.Extension, "Extension");
	
	Return Result;
EndFunction

// Returns the flag indicating whether items can be added or edited.
//
Function HasRightToAdd() Export
	Return AccessRight("Insert", Metadata.Catalogs.WorldCountries);
EndFunction

Function FiilInDataOfAutoCompleteSelectionByCountries(Val Parameters) Export
	
	ChoiceData = New ValueList;

	// Simulating platform behavior - searching by all available search fields, generating a detailed list.
	
	// It is assumed that the catalog and classifier fields are identical, except for one field unavailable in the classifier:
	// the Ref field.
	Query = New Query;
	Query.TempTablesManager = New TempTablesManager;
	
	FilterParameterPrefix = "FilterParameters";
	
	// Common filter by parameters
	FilterTemplate = "TRUE";
	For Each KeyValue In Parameters.Filter Do
		FieldValue = KeyValue.Value;
		FieldName      = KeyValue.Key;
		ParameterName = FilterParameterPrefix + FieldName;
		
		If TypeOf(FieldValue)=Type("Array") Then
			FilterTemplate = FilterTemplate + " AND %1." + FieldName + " IN (&" + ParameterName + ")";
		Else
			FilterTemplate = FilterTemplate + " AND %1." + FieldName + " = &" + ParameterName;
		EndIf;
		
		Query.SetParameter(ParameterName, KeyValue.Value);
	EndDo;
	
	// Additional filters
	If Parameters.Property("ChoiceFoldersAndItems") Then
		If Parameters.ChoiceFoldersAndItems = FoldersAndItemsUse.Folders Then
			
			FilterTemplate = FilterTemplate + " AND %1.IsFolder";
			
		ElsIf Parameters.ChoiceFoldersAndItems = FoldersAndItemsUse.Items Then
			
			FilterTemplate = FilterTemplate + " AND (NOT %1.IsFolder)";
			
		EndIf;
	EndIf;
	
	// Data sources
	If (Parameters.Property("OnlyClassifierData") AND Parameters.OnlyClassifierData) Then
		// Selecting from classifier only.
		QueryTemplate = "
		|SELECT TOP 50
		|	NULL                       AS Ref,
		|	Classifier.Code          AS Code,
		|	Classifier.Description AS Description,
		|	FALSE                       AS DeletionMark,
		|	%2                         AS Presentation
		|FROM
		|	Classifier AS Classifier
		|WHERE
		|	Classifier.%1 LIKE &SearchString
		|	AND (
		|		" + StrReplace(FilterTemplate, "%1", "Classifier") + "
		|	)
		|ORDER BY
		|	Classifier.%1
		|";
	Else
		// Selecting both from catalog and classifier.
		QueryTemplate = "
		|SELECT TOP 50 
		|	WorldCountries.Ref                                             AS Ref,
		|	ISNULL(WorldCountries.Code, Classifier.Code)                   AS Code,
		|	ISNULL(WorldCountries.Description, Classifier.Description) AS Description,
		|	ISNULL(WorldCountries.DeletionMark, FALSE)                    AS DeletionMark,
		|
		|	CASE WHEN WorldCountries.Ref IS NULL THEN 
		|		%2 
		|	ELSE 
		|		%3
		|	END AS Presentation
		|
		|FROM
		|	Catalog.WorldCountries AS WorldCountries
		|FULL JOIN
		|	Classifier
		|ON
		|	Classifier.Code = WorldCountries.Code
		|	AND Classifier.Description = WorldCountries.Description
		|WHERE 
		|	(WorldCountries.%1 LIKE &SearchString OR Classifier.%1 LIKE &SearchString)
		|	AND (" + StrReplace(FilterTemplate, "%1", "Classifier") + ")
		|	AND (" + StrReplace(FilterTemplate, "%1", "WorldCountries") + ")
		|
		|ORDER BY
		|	ISNULL(WorldCountries.%1, Classifier.%1)
		|";
	EndIf;
	
	FieldsNames = SearchFields();
	
	// Code and Description are the key fields for catalog-to-classifier mapping. Processing of these fields is required.
	FieldNamesString = "," + StrReplace(FieldsNames.FieldNamesString, " ", "");
	FieldNamesString = StrReplace(FieldNamesString, ",Code", "");
	FieldNamesString = StrReplace(FieldNamesString, ",Description", "");
	
	Query.Text = "
	|SELECT
	|	Code, Description " + FieldNamesString + "
	|INTO
	|	Classifier
	|FROM
	|	&Classifier AS Classifier
	|INDEX BY
	|	Code, Description
	|	" + FieldNamesString + "
	|";
	Query.SetParameter("Classifier", ContactsManager.ClassifierTable());
	Query.Execute();
	Query.SetParameter("SearchString", EscapeLikeCharacters(Parameters.SearchString) + "%");
	
	For Each FieldData In FieldsNames.FieldList Do
		QueryText = StrReplace(QueryTemplate, "%1", FieldData.Name);
		QueryText = StrReplace(QueryText, "%2", StrReplace(FieldData.PresentationTemplate, "%1", "Classifier"));
		Query.Text = StrReplace(QueryText, "%3", StrReplace(FieldData.PresentationTemplate, "%1", "WorldCountries"));
		
		Result = Query.Execute();
		If Not Result.IsEmpty() Then
			StandardProcessing = False;
			
			Selection = Result.Select();
			While Selection.Next() Do
				If ValueIsFilled(Selection.Ref) Then
					// Catalog data
					ChoiceItem = Selection.Ref;
				Else
					// Classifier data.
					SelectionResult = New Structure("Code, Description", 
					Selection.Code, Selection.Description);
					
					ChoiceItem = New Structure("Value, DeletionMark, Warning",
					SelectionResult, Selection.DeletionMark, Undefined);
				EndIf;
				
				ChoiceData.Add(ChoiceItem, Selection.Presentation);
			EndDo;
			
			Break;
		EndIf;
	EndDo;
	
	Return ChoiceData;
	
EndFunction

// Returns search fields in the preferred order for the World countries catalog.
//
// Returns:
//    Array - contains structures with the following fields:
//      * Name - String - a search attribute name.
//      * PresentationPattern - String - template used to generate presentation value based on 
//                                       attribute names. Example: "%1.Description (%1.Code)". 
//                                       Description and Code are attribute names,
//                                       %1 - a placeholder used to pass a table alias.
//
Function SearchFields()
	Result = New Array;
	FieldsList = Catalogs.WorldCountries.EmptyRef().Metadata().InputByString;
	FieldBorder = FieldsList.Count() - 1;
	AllNamesString = "";
	
	SeparatorPresentation = ", ";
	PresentationSeparator = " + """ + SeparatorPresentation + """ + ";
	
	For Index=0 To FieldBorder Do
		FieldName = FieldsList[Index].Name;
		AllNamesString = AllNamesString + "," + FieldName;
		
		PresentationTemplate = "%1." + FieldName;
		
		OtherFields = "";
		For Position=0 To FieldBorder Do
			If Position<>Index Then
				OtherFields = OtherFields + PresentationSeparator + FieldsList[Position].Name;
			EndIf;
		EndDo;
		If Not IsBlankString(OtherFields) Then
			PresentationTemplate = PresentationTemplate
				+ " + "" ("" + " 
				+ "%1." + Mid(OtherFields, StrLen(PresentationSeparator) + 1) 
				+ " + "")""";
		EndIf;
		
		Result.Add(
			New Structure("Name, PresentationTemplate", FieldName, PresentationTemplate));
	EndDo;
	
	Return New Structure("FieldList, FieldNamesString", Result, Mid(AllNamesString, 2));
EndFunction

// Shields characters used in LIKE query function.
//
Function EscapeLikeCharacters(Val Text, Val Escape = "\")
	Result = Text;
	LikeCharacters = "%_[]^" + Escape;
	
	For Position=1 To StrLen(LikeCharacters) Do
		CurrentChar = Mid(LikeCharacters, Position, 1);
		Result = StrReplace(Result, CurrentChar, Escape + CurrentChar);
	EndDo;
	
	Return Result;
EndFunction

#EndRegion

// For backward compatibility.

#Region PrivateForCompatibility

// Converts XML into XDTO object of contact information.
//
//  Parameters:
//      Text - String - an XML string of contact information.
//      ExpectedKind - CatalogRef.ContactsKinds, EnumRef.ContactsTypes, Structure -
//      ConversionResult - Structure - if set, the following info is written to properties:
//        * ErrorText - String - details of read errors. The return value of the function will be 
//                                 correct but not filled.
//
// Returns:
//      XDTOObject - contact information matching the XDTO package ContactInformation.
//   
Function ContactsFromXML(Val Text, Val ExpectedKind = Undefined, ConversionResult = Undefined, Val Presentation = "") Export
	
	ExpectedType = ContactInformationManagementInternalCached.ContactInformationKindType(ExpectedKind);
	
	If ConversionResult = Undefined Or TypeOf(ConversionResult) <> Type("Structure") Then
		ConversionResult = New Structure;
	EndIf;
	ConversionResult.Insert("InfoCorrected", False);
	
	EnumAddress                 = Enums.ContactInformationTypes.Address;
	EnumEmailAddress = Enums.ContactInformationTypes.EmailAddress;
	EnumSkype                 = Enums.ContactInformationTypes.Skype;
	EnumWebpage           = Enums.ContactInformationTypes.WebPage;
	EnumPhone               = Enums.ContactInformationTypes.Phone;
	EnumFax                  = Enums.ContactInformationTypes.Fax;
	EnumOther                = Enums.ContactInformationTypes.Other;
	
	Namespace = ContactsManagerClientServer.Namespace();
	
	If ContactsManagerClientServer.IsXMLContactInformation(Text) Then
		XMLReader = New XMLReader;
		
		If Metadata.CommonModules.Find("AddressManager") <> Undefined Then
			ModuleAddressManager = Common.CommonModule("AddressManager");
			Text = ModuleAddressManager.BeforeReadXDTOContactInformation(Text);
		EndIf;
		
		XMLReader.SetString(Text);
		
		ErrorText = Undefined;
		
		ContactsRestorationRequired = False;
		
		Try
			Result = XDTOFactory.ReadXML(XMLReader, XDTOFactory.Type(Namespace, "ContactInformation"));
			
			If ExpectedType = Enums.ContactInformationTypes.Address AND XDTOContactsEmpty(Result) Then
				ContactsRestorationRequired = True;
			EndIf;
			
		Except
			
			ContactsRestorationRequired = True;
			
		EndTry;
		
		If ContactsRestorationRequired Then
			ErrorCauseDetails = NStr("ru='Сведения контактной информации были восстановлены после сбоя.'; en = 'Data on contact information recovered after failure.'; pl = 'Informacje kontaktowe zostały przywrócone po awarii.';es_ES = 'Los detalles de la información de contacto han sido restablecidos después del fallo.';es_CO = 'Los detalles de la información de contacto han sido restablecidos después del fallo.';tr = 'İletişim bilgileri başarısız olduktan sonra geri yüklendi.';it = 'Dati sulle informazioni di contatto recuperate dopo l''errore.';de = 'Die Kontaktinformationen wurden nach einem Ausfall wiederhergestellt.'");
			If ValueIsFilled(Presentation) Then
				Result = XDTOContactsByPresentation(Presentation, ExpectedKind);
				If StrCompare(Result.Presentation, Presentation) <> 0  Then
					ErrorText = ErrorCauseDetails;
					ConversionResult.Insert("ErrorText", ErrorText);
				EndIf;
				
			EndIf;
			
			// Invalid XML format
			WriteLogEvent(EventLogEvent(),
				EventLogLevel.Warning, , Text, ErrorCauseDetails + Chars.LF
					+ ErrorInfo().Description);
				
			ConversionResult.Insert("InfoCorrected", True);
		EndIf;
		
		If ErrorText = Undefined AND ExpectedType <> Undefined Then
			
			If Result = Undefined Then
				ErrorText = StrReplace(NStr("ru='Сведения контактной информации %ExpectedKind% были повреждены или некорректно заполнены.'; en = 'A part of %ExpectedKind% contact information was damaged or populated incorrectly.'; pl = 'Informacje kontaktowe %ExpectedKind% zostały uszkodzone lub niepoprawnie wypełnione.';es_ES = 'Los detalles de la información de contacto %ExpectedKind% han sido dañados o rellenados incorrectamente.';es_CO = 'Los detalles de la información de contacto %ExpectedKind% han sido dañados o rellenados incorrectamente.';tr = 'İletişim bilgileri %ExpectedKind% bozuk veya yanlış doldurulmuş.';it = 'Un a parte delle informazioni di contatto %ExpectedKind% è danneggiato o compilato non correttamente.';de = 'Kontaktinformationen %ExpectedKind% wurde beschädigt oder falsch ausgefüllt.'"),
					"%ExpectedKind%", String(ExpectedKind));
			Else
				// Checking for type mapping.
				TypeFound = ?(Result.Content = Undefined, Undefined, Result.Content.Type());
				
				MessageTemplate = StrReplace(NStr("ru='Сведения %1 контактной информации %ExpectedKind% были повреждены или некорректно заполнены.'; en = 'The %1 part of %ExpectedKind% contact information was damaged or populated incorrectly.'; pl = 'Informacje %1 kontaktowe %ExpectedKind% zostały uszkodzone lub niepoprawnie wypełnione.';es_ES = 'Los detalles %1 de la información de contacto %ExpectedKind% han sido dañados o rellenados incorrectamente.';es_CO = 'Los detalles %1 de la información de contacto %ExpectedKind% han sido dañados o rellenados incorrectamente.';tr = 'İletişim bilgileri %1 %ExpectedKind% bozuk veya yanlış doldurulmuş.';it = '%1 parte delle informazioni di contatto %ExpectedKind% è danneggiato o compilato non correttamente.';de = 'Kontaktinformationen %1 %ExpectedKind% wurde beschädigt oder falsch ausgefüllt.'"),
					"%ExpectedKind%", String(ExpectedKind));
				If ExpectedType = EnumAddress AND TypeFound <> XDTOFactory.Type(Namespace, "Address") Then
					ErrorText = StringFunctionsClientServer.SubstituteParametersToString(MessageTemplate, NStr("ru='об адресе'; en = 'about address'; pl = 'o adresie';es_ES = 'de la dirección';es_CO = 'de la dirección';tr = 'adres hakkında';it = 'a proposito dell''indirizzo';de = 'über die Adresse'"));
				ElsIf ExpectedType = EnumEmailAddress AND TypeFound <> XDTOFactory.Type(Namespace, "Email") Then
					ErrorText = StringFunctionsClientServer.SubstituteParametersToString(MessageTemplate, NStr("ru='эл. почта'; en = 'email'; pl = 'poczta e-mail';es_ES = 'del correo electrónico';es_CO = 'del correo electrónico';tr = 'e-posta';it = 'email';de = 'E-Mail'"));
				ElsIf ExpectedType = EnumWebpage AND TypeFound <> XDTOFactory.Type(Namespace, "Website") Then
					ErrorText = StringFunctionsClientServer.SubstituteParametersToString(MessageTemplate, NStr("ru='веб-страницы'; en = 'web page'; pl = 'strony internetowej';es_ES = 'de la página web';es_CO = 'de la página web';tr = 'web sayfası';it = 'pagina internet';de = 'Webseiten'"));
				ElsIf ExpectedType = EnumPhone AND TypeFound <> XDTOFactory.Type(Namespace, "PhoneNumber") Then
					ErrorText = StringFunctionsClientServer.SubstituteParametersToString(MessageTemplate, NStr("ru='о номере телефона'; en = 'about phone number'; pl = 'o numerze telefonu';es_ES = 'del número de teléfono';es_CO = 'del número de teléfono';tr = 'telefon numarası hakkında';it = 'a proposito del numero di telefono';de = 'über die Telefonnummer'"));
				ElsIf ExpectedType = EnumFax AND TypeFound <> XDTOFactory.Type(Namespace, "FaxNumber") Then
					ErrorText = StringFunctionsClientServer.SubstituteParametersToString(MessageTemplate, NStr("ru='о номере факса'; en = 'about fax number'; pl = 'o numerze faksu';es_ES = 'del número de fax';es_CO = 'del número de fax';tr = 'faks numarası hakkında';it = 'a proposito del numero di fax';de = 'über die Faxnummer'"));
				ElsIf ExpectedType = EnumSkype AND TypeFound <> XDTOFactory.Type(Namespace, "Skype") Then
					ErrorText = StringFunctionsClientServer.SubstituteParametersToString(MessageTemplate, NStr("ru='о логине Skype'; en = 'about Skype username'; pl = 'o loginie Skype';es_ES = 'del login en Skype';es_CO = 'del login en Skype';tr = 'Skype login hakkında';it = 'a proposito dell''utente Skype';de = 'über die Anmeldung von Skype'"));
				ElsIf ExpectedType = EnumOther AND TypeFound <> XDTOFactory.Type(Namespace, "Other") Then
					ErrorText = StringFunctionsClientServer.SubstituteParametersToString(MessageTemplate, NStr("ru='о дополнительной'; en = 'about additional'; pl = 'o dodatkowej';es_ES = 'de adicional';es_CO = 'de adicional';tr = 'ek hakkında';it = 'a proposito dell''aggiuntivo';de = 'über ein zusätzliches'"));
				EndIf;
			EndIf;
		EndIf;
		
		If ErrorText = Undefined Then
			// Successfully read
			Return Result;
		EndIf;
		
		ConversionResult.Insert("ErrorText", ErrorText);
		
		// Returning an empty object.
		Text = "";
	EndIf;
	
	If TypeOf(Text) = Type("ValueList") Then
		Presentation = "";
		IsNew = Text.Count() = 0;
	ElsIf IsBlankString(Presentation) Then
		Presentation = String(Text);
		IsNew = IsBlankString(Text);
	Else
		IsNew = False;
	EndIf;
	
	Result = XDTOFactory.Create(XDTOFactory.Type(Namespace, "ContactInformation"));
	
	// Parsing
	If ExpectedType = EnumAddress Then
		If IsNew Then
			Result.Content = XDTOFactory.Create(XDTOFactory.Type(Namespace, "Address"));
		Else
			Result = XMLAddressInXDTO(Text, Presentation, ExpectedType);
		EndIf;
		
	ElsIf ExpectedType = EnumPhone Then
		If IsNew Then
			Result.Content = XDTOFactory.Create(XDTOFactory.Type(Namespace, "PhoneNumber"));
		Else
			Result = PhoneDeserialization(Text, Presentation, ExpectedType)
		EndIf;
		
	ElsIf ExpectedType = EnumFax Then
		If IsNew Then
			Result.Content = XDTOFactory.Create(XDTOFactory.Type(Namespace, "FaxNumber"));
		Else
			Result = FaxDeserialization(Text, Presentation, ExpectedType)
		EndIf;
		
	ElsIf ExpectedType = EnumEmailAddress Then
		If IsNew Then
			Result.Content = XDTOFactory.Create(XDTOFactory.Type(Namespace, "Email"));
		Else
			Result = OtherContactInformationDeserialization(Text, Presentation, ExpectedType)
		EndIf;
	ElsIf ExpectedType = EnumSkype Then
		If IsNew Then
			Result.Content = XDTOFactory.Create(XDTOFactory.Type(Namespace, "Skype"));
		Else
			Result = OtherContactInformationDeserialization(Text, Presentation, ExpectedType)
		EndIf;
	ElsIf ExpectedType = EnumWebpage Then
		If IsNew Then
			Result.Content = XDTOFactory.Create(XDTOFactory.Type(Namespace, "Website"));
		Else
			Result = OtherContactInformationDeserialization(Text, Presentation, ExpectedType)
		EndIf;
		
	ElsIf ExpectedType = EnumOther Then
		If IsNew Then
			Result.Content = XDTOFactory.Create(XDTOFactory.Type(Namespace, "Other"));
		Else
			Result = OtherContactInformationDeserialization(Text, Presentation, ExpectedType)
		EndIf;
		
	Else
		ErrorText = NStr("ru = 'Сведения о типе контактной информации %1 были повреждены или некорректно заполнены,
								|т.к. обязательное поле тип не заполнено.'; 
								|en = 'Information on contact information type %1 was damaged or filled in incorrectly
								|as the required ""Type"" field is not filled in.'; 
								|pl = 'Informacje o rodzaju informacji kontaktowych %1 zostały uszkodzone lub niepoprawnie wypełnione,
								|ponieważ obowiązkowe pole rodzaj nie zostało wypełnione.';
								|es_ES = 'Los detalles del tipo la información de contacto %1 han sido dañados o rellenados incorrectamente,
								|porque el campo obligatorio tipo no está rellenado.';
								|es_CO = 'Los detalles del tipo la información de contacto %1 han sido dañados o rellenados incorrectamente,
								|porque el campo obligatorio tipo no está rellenado.';
								|tr = 'İletişim bilgileri türü hakkındaki %1bilgileri bozuk veya yanlış doldurulmuştur, 
								|çünkü zorunlu tür alanı doldurulmamıştır.';
								|it = 'Le informazioni sulla tipologia di informazioni di contatto %1 è stata danneggiata o compilata non correttamente
								|dato che il campo richiesto ""Tipo"" non è stato compilato.';
								|de = 'Informationen über die Art der Kontaktinformationen %1 wurden beschädigt oder falsch ausgefüllt,
								|da das Pflichtfeld nicht ausgefüllt ist.'");
		ErrorText =  StringFunctionsClientServer.SubstituteParametersToString(ErrorText, ?(ValueIsFilled(ExpectedKind), """" + ExpectedKind.Description + """", ""));
		ConversionResult.Insert("ErrorText", ErrorText);
	EndIf;
	
	Return Result;
	
EndFunction

Function XDTOContactsEmpty(Val Result)
	
	Composition = Result.Properties().Get("Content");
	If Composition <> Undefined Then
		Information = Result.Content.Properties().Get("Content");
		If Information <> Undefined Then
			If TypeOf(Result.Content.Content) = Type("String") Then
				Return IsBlankString(Result.Content.Content);
			ElsIf TypeOf(Result.Content.Content) = Type("XDTODataObject") Then
				For each XDTOField In Result.Content.Content.Properties() Do
					If XDTOField.Name = "AddlAddressItem" Or XDTOField.Name = "MunicipalEntityDistrictProperty" Then
						Continue;
					ElsIf ValueIsFilled(Result.Content.Content.Get(XDTOField.Name)) Then
						Return False;
					EndIf;
				EndDo;
			EndIf;
		Else
			ValueField = Result.Content.Properties().Get("Value");
			If ValueField <> Undefined Then
				Return IsBlankString(Result.Content.Get("Value"));
			EndIf;
		EndIf;
		
	EndIf;
	
	Return True;
	
EndFunction

// Returns the flag indicating that the passed CI object contains data.
//
// Parameters:
//      ContactInformation - Structure - contact information data to be checked.
//
// Returns:
//     Boolean - data availability flag.
//
Function ContactsFilledIn(Val  ContactInformation) Export
	
	Return HasFilledContactsProperties(ContactInformation);
	
EndFunction

// Parameters: Owner - Structure, Undefined
//
Function HasFilledContactsProperties(Val Owner)
	
	If Owner = Undefined Then
		Return False;
	EndIf;
	
	// List of the current owner properties ignored upon comparison - contact information specifics.
	FieldsListToCheck = New Array;
	FieldsListToCheck.Add("Value");
	FieldsListToCheck.Add("Type");
	If ContactsManagerClientServer.IsAddressType(Owner.Type) Then
		FieldsListToCheck.Add("Country");
	EndIf;
	
	If Metadata.CommonModules.Find("AddressManagerClientServer") <> Undefined Then
		
		ModuleAddressManagerClientServer = Common.CommonModule("AddressManagerClientServer");
		CommonClientServer.SupplementArray(FieldsListToCheck, ModuleAddressManagerClientServer.AddressLevelsNames(Owner, True));
		
	EndIf;
	
	For each FieldName In FieldsListToCheck Do
		If Owner.Property(FieldName) <> Undefined AND ValueIsFilled(Owner[FieldName]) Then
			Return True;
		EndIf;
	EndDo;
	
	Return False;
	
EndFunction

Procedure ReplaceInStructureUndefinedWithEmptyString(StructureForCrawl) Export
	
	For each KeyValue In StructureForCrawl Do
		If TypeOf(KeyValue.Value) = Type("Structure")Then
			ReplaceInStructureUndefinedWithEmptyString(StructureForCrawl[KeyValue.Key]);
		ElsIf KeyValue.Value = Undefined Then
			StructureForCrawl[KeyValue.Key] = "";
		EndIf;
	EndDo;

EndProcedure

Function PhoneFaxDeserialization(FieldsValues, Presentation = "", ExpectedType = Undefined)
	
	If ContactsManagerClientServer.IsXMLContactInformation(FieldsValues) Then
		// Common format of contact information.
		Return ContactsFromXML(FieldsValues, ExpectedType);
	EndIf;
	
	Namespace = ContactsManagerClientServer.Namespace();
	
	If ExpectedType = Enums.ContactInformationTypes.Phone Then
		Data = XDTOFactory.Create(XDTOFactory.Type(Namespace, "PhoneNumber"));
		
	ElsIf ExpectedType = Enums.ContactInformationTypes.Fax Then
		Data = XDTOFactory.Create(XDTOFactory.Type(Namespace, "FaxNumber"));
		
	ElsIf ExpectedType = Undefined Then
		// This data is considered to be a phone number
		Data = XDTOFactory.Create(XDTOFactory.Type(Namespace, "PhoneNumber"));
		
	Else
		Raise NStr("ru='Ошибка десериализации контактной информации, ожидается телефон или факс'; en = 'Contact information deserialization error. Phone or fax number is expected'; pl = 'Wystąpił błąd podczas oczekiwanego deserializowania informacji kontaktowych, numeru telefonu lub faksu';es_ES = 'Ha ocurrido un error al deserializar la información de contacto, número de teléfono o fax están esperados';es_CO = 'Ha ocurrido un error al deserializar la información de contacto, número de teléfono o fax están esperados';tr = 'İletişim bilgilerinin seriden paralele çevrilmesi sırasında bir hata oluştu, telefon veya faks numarası bekleniyor';it = 'Errore deserializzazione informazioni di contatto. Telefono o numero di fax è atteso';de = 'Beim Deserialisieren der Kontaktinformationen, der Telefonnummer oder des Faxes ist ein Fehler aufgetreten'");
	EndIf;
	
	Result = XDTOFactory.Create(XDTOFactory.Type(Namespace, "ContactInformation"));
	Result.Content        = Data;
	
	// From key-value pairs
	FieldValueList = Undefined;
	If TypeOf(FieldsValues)=Type("ValueList") Then
		FieldValueList = FieldsValues;
	ElsIf Not IsBlankString(FieldsValues) Then
		FieldValueList = ContactsManagerClientServer.ConvertStringToFieldList(FieldsValues);
	EndIf;
	
	PresentationField = "";
	If FieldValueList <> Undefined Then
		For Each FieldValue In FieldValueList Do
			Field = Upper(FieldValue.Presentation);
			
			If Field = "COUNTRYCODE" Then
				Data.CountryCode = FieldValue.Value;
				
			ElsIf Field = "CITYCODE" Then
				Data.CityCode = FieldValue.Value;
				
			ElsIf Field = "PHONENUMBER" Then
				Data.Number = FieldValue.Value;
				
			ElsIf Field = "EXTENSION" Then
				Data.Extension = FieldValue.Value;
				
			ElsIf Field = "PRESENTATION" Then
				PresentationField = TrimAll(FieldValue.Value);
				
			EndIf;
			
		EndDo;
		
		// Presentation with priorities.
		If Not IsBlankString(Presentation) Then
			Result.Presentation = Presentation;
		ElsIf ValueIsFilled(PresentationField) Then
			Result.Presentation = PresentationField;
		Else
			Result.Presentation = PhonePresentation(Data);
		EndIf;
		
		Return Result;
	EndIf;
	
	// Parsing from the presentation.
	
	// Groups of numbers separated by non-digits: a country, a city, a number, and an extension.
	// Extension includes non-space characters on the left and on the right.
	Position = 1;
	Data.CountryCode  = FindSubstringOfNumbers(Presentation, Position);
	CityBeginning = Position;
	
	Data.CityCode  = FindSubstringOfNumbers(Presentation, Position);
	Data.Number      = FindSubstringOfNumbers(Presentation, Position, " -");
	
	Extension = TrimAll(Mid(Presentation, Position));
	If StrStartsWith(Extension, ",") Then
		Extension = TrimL(Mid(Extension, 2));
	EndIf;
	If Upper(Left(Extension, 3 ))= "EXT" Then
		Extension = TrimL(Mid(Extension, 4));
	EndIf;
	If Upper(Left(Extension, 1 ))= "." Then
		Extension = TrimL(Mid(Extension, 2));
	EndIf;
	Data.Extension = TrimAll(Extension);
	
	// Fixing possible errors.
	If IsBlankString(Data.Number) Then
		If StrStartsWith(TrimL(Presentation), "+") Then
			// An attempt to specify the area code explicitly is detected. Leaving the area code "as is".
			Data.CityCode  = "";
			Data.Number      = RemoveNonDigitCharacters(Mid(Presentation, CityBeginning));
			Data.Extension = "";
		Else
			Data.CountryCode  = "";
			Data.CityCode  = "";
			Data.Number      = Presentation;
			Data.Extension = "";
		EndIf;
	EndIf;
	
	Result.Presentation = Presentation;
	Return Result;
EndFunction

Function DeserializingPhoneFaxInJSON(FieldsValues, Presentation = "", ExpectedType = Undefined)
	
	If ContactsManagerClientServer.IsXMLContactInformation(FieldsValues) Then
		// Common format of contact information.
		Return ContactsFromXML(FieldsValues, ExpectedType);
	EndIf;
	
	Data = ContactsManagerClientServer.NewContactInformationDetails(ExpectedType);
	
	// From key-value pairs
	FieldValueList = Undefined;
	If TypeOf(FieldsValues)=Type("ValueList") Then
		FieldValueList = FieldsValues;
	ElsIf Not IsBlankString(FieldsValues) Then
		FieldValueList = ContactsManagerClientServer.ConvertStringToFieldList(FieldsValues);
	EndIf;
	
	PresentationField = "";
	If FieldValueList <> Undefined Then
		For Each FieldValue In FieldValueList Do
			Field = Upper(FieldValue.Presentation);
			
			If Field = "COUNTRYCODE" Then
				Data.CountryCode = FieldValue.Value;
				
			ElsIf Field = "CITYCODE" Then
				Data.AreaCode = FieldValue.Value;
				
			ElsIf Field = "PHONENUMBER" Then
				Data.Number = FieldValue.Value;
				
			ElsIf Field = "EXTENSION" Then
				Data.ExtNumber = FieldValue.Value;
				
			ElsIf Field = "PRESENTATION" Then
				PresentationField = TrimAll(FieldValue.Value);
				
			EndIf;
			
		EndDo;
		
		// Presentation with priorities.
		If Not IsBlankString(Presentation) Then
			Data.Value = Presentation;
		ElsIf ValueIsFilled(PresentationField) Then
			Data.Value = PresentationField;
		Else
			Data.Value = PhonePresentation(Data);
		EndIf;
		
		Return Data;
	EndIf;
	
	// Parsing from the presentation.
	
	// Groups of numbers separated by non-digits: a country, a city, a number, and an extension.
	// Extension includes non-space characters on the left and on the right.
	Position = 1;
	Data.CountryCode  = FindSubstringOfNumbers(Presentation, Position);
	CityBeginning = Position;
	
	Data.AreaCode  = FindSubstringOfNumbers(Presentation, Position);
	Data.Number    = FindSubstringOfNumbers(Presentation, Position, " -");
	
	Extension = TrimAll(Mid(Presentation, Position));
	If StrStartsWith(Extension, ",") Then
		Extension = TrimL(Mid(Extension, 2));
	EndIf;
	If Upper(Left(Extension, 3 ))= "EXT" Then
		Extension = TrimL(Mid(Extension, 4));
	EndIf;
	If Upper(Left(Extension, 1 ))= "." Then
		Extension = TrimL(Mid(Extension, 2));
	EndIf;
	Data.ExtNumber = TrimAll(Extension);
	
	// Fixing possible errors.
	If IsBlankString(Data.Number) Then
		If StrStartsWith(TrimL(Presentation), "+") Then
			// An attempt to specify the area code explicitly is detected. Leaving the area code "as is".
			Data.AreaCode  = "";
			Data.Number      = RemoveNonDigitCharacters(Mid(Presentation, CityBeginning));
			Data.ExtNumber = "";
		Else
			Data.CountryCode  = "";
			Data.AreaCode  = "";
			Data.Number      = Presentation;
			Data.ExtNumber = "";
		EndIf;
	EndIf;
	
	Data.Value = Presentation;
	Return Data;
EndFunction

// Returns the first digit substring found in the string. The StartPosition parameter is changed to the first non-digit character.
//
Function FindSubstringOfNumbers(Text, StartPosition = Undefined, AllowedBesidesNumbers = "")
	
	If StartPosition = Undefined Then
		StartPosition = 1;
	EndIf;
	
	Result = "";
	EndPosition = StrLen(Text);
	BeginningSearch  = True;
	
	While StartPosition <= EndPosition Do
		Char = Mid(Text, StartPosition, 1);
		IsDigit = Char >= "0" AND Char <= "9";
		
		If BeginningSearch Then
			If IsDigit Then
				Result = Result + Char;
				BeginningSearch = False;
			EndIf;
		Else
			If IsDigit Or StrFind(AllowedBesidesNumbers, Char) > 0 Then
				Result = Result + Char;    
			Else
				Break;
			EndIf;
		EndIf;
		
		StartPosition = StartPosition + 1;
	EndDo;
	
	// Discarding possible hanging separators on the right.
	Return RemoveNonDigitCharacters(Result, AllowedBesidesNumbers, False);
	
EndFunction

Function RemoveNonDigitCharacters(Text, AllowedBesidesNumbers = "", Direction = True)
	
	Length = StrLen(Text);
	If Direction Then
		// Trimming on the left.
		Index = 1;
		End  = 1 + Length;
		Step    = 1;
	Else
		// Trimming on the right.
		Index = Length;
		End  = 0;
		Step    = -1;
	EndIf;
	
	While Index <> End Do
		Char = Mid(Text, Index, 1);
		IsDigit = (Char >= "0" AND Char <= "9") Or StrFind(AllowedBesidesNumbers, Char) = 0;
		If IsDigit Then
			Break;
		EndIf;
		Index = Index + Step;
	EndDo;
	
	If Direction Then
		// Trimming on the left.
		Return Right(Text, Length - Index + 1);
	EndIf;
	
	// Trimming on the right.
	Return Left(Text, Index);
	
EndFunction

#EndRegion

#Region PrivateForWorkingWithXML

// Returns the matching value of the ContactsType enumeration by the XML string.
//
// Parameters:
//    XMLString - a string describing contact information.
//
// Returns:
//     EnumRef.ContactsType - a result.
//
Function ContactInformationType(Val XMLString) Export
	Return ValueFromXMLString(XSLT_ContactInformationTypeByXMLString(XMLString));
EndFunction

// Reads the string containing composition of the contact information value.
// If the composition value has a complex type, returns undefined.
//
// Parameters:
//    Text - String - an XML string of contact information. Can be modified.
//
// Returns:
//    String - composition XML value.
//    Undefined - the Composition property is not found.
//
Function ContactInformationCompositionString(Val Text, Val NewValue = Undefined) Export
	Read = New XMLReader;
	Read.SetString(Text);
	XDTODataObject= XDTOFactory.ReadXML(Read, 
		XDTOFactory.Type(ContactsManagerClientServer.Namespace(), "ContactInformation"));
	
	Composition = XDTODataObject.Content;
	If Composition <> Undefined 
		AND Composition.Properties().Get("Value") <> Undefined
		AND TypeOf(Composition.Value) = Type("String") Then
		Return Composition.Value;
	EndIf;
	
	Return Undefined;
EndFunction

// Compares two instances of contact information.
//
// Parameters:
//    Data1 - XTDOObject - an object with contact information.
//            - String - contact information in XML format.
//            - Structure - contact information details. The following fields are expected:
//                 * FieldsValues - String, Structure, ValueList, Map - contact information fields.
//                 * Presentation - String - a presentation. Used when presentation cannot be 
//                                            extracted from FieldsValues (the Presentation field is not available).
//                 * Comment - String - a comment. Used when a comment cannot be extracted from 
//                                          FieldsValues.
//                 * ContactsKind - CatalogRef.ContactsKinds,
//                                             EnumRef.ContactsTypes, Structure - 
//                                             Used when a type cannot be extracted from FieldsValues.
//    Data2 - XTDOObject, String, Structure - similar to Data1.
//
// Returns:
//     ValueTable: - a table of different fields with the following columns:
//        * Path - String - XPath identifying the value difference. The "ContactInformationType" value
//                               means that passed contact information sets have different types.
//        * Details - String - details of a different attribute in terms of the subject field.
//        * Value1 - String - a value matching the object passed in the Data1 parameter.
//        * Value2 - String - a value matching the object passed in Data2 parameter.
//
Function ContactInformationDifferences(Val Data1, Val Data2) Export
	ContactInformationData1 = TransformContactInformationXML(Data1);
	ContactInformationData2 = TransformContactInformationXML(Data2);
	
	ContactInformationType = ContactInformationData1.ContactInformationType;
	If ContactInformationType <> ContactInformationData2.ContactInformationType Then
		// Type mismatch, comparison canceled.
		Result = New ValueTable;
		Columns   = Result.Columns;
		ResultString = Result.Add();
		ResultString[Columns.Add("Path").Name]      = "ContactInformationType";
		ResultString[Columns.Add("Value1").Name] = ContactInformationData1.ContactInformationType;
		ResultString[Columns.Add("Value2").Name] = ContactInformationData2.ContactInformationType;
		ResultString[Columns.Add("Details").Name]  = NStr("ru = 'Различные типы контактной информации'; en = 'Contact information type mismatch'; pl = 'Niedopasowanie typu informacji kontaktowej';es_ES = 'Discrepancia del tipo de la información de contacto';es_CO = 'Discrepancia del tipo de la información de contacto';tr = 'İletişim bilgileri türü uyuşmazlığı';it = 'Tipo di contatto informazioni non corrispondenti';de = 'Kontaktinformationstyp stimmt nicht überein'");
		Return Result;
	EndIf;
	
	TextXMLDifferences = XSLT_ValueTableDifferencesXML(ContactInformationData1.XMLData, ContactInformationData2.XMLData);
	
	// Providing interpretation depending on the type.
	Return ValueFromXMLString( XSLT_ContactsXMLDifferenceInterpretation(
			TextXMLDifferences, ContactInformationType));
	
EndFunction

// Converts contact information into XML.
//
// Parameters:
//    Data - String - details of XML or JSON contact information.
//           - XTDOObject - contact information details.
//           - Structure - contact information details. The following fields are expected:
//                 * FieldsValues - String, Structure, ValueList, Map - contact information fields.
//                 * Presentation - String - a presentation. Used when presentation cannot be 
//                                            extracted from FieldsValues (the Presentation field is not available).
//                 * Comment - String - a comment. Used when a comment cannot be extracted from 
//                                          FieldsValues.
//                 * ContactsKind - CatalogRef.ContactsKinds,
//                                             EnumRef.ContactsTypes, Structure -
//                                             Used when a type cannot be extracted from FieldsValues.
//
// Returns:
//     Structure - contains the following fields:
//        * ContactInformationType - EnumRef.ContactInformationTypes
//        * XMLData - String - an XML text.
//
Function TransformContactInformationXML(Val Data) Export
	
	XMLString               = "";
	FieldsValues           = "";
	Comment             = Undefined;
	ContactInformationType = Undefined;
	
	If TypeOf(Data) = Type("XDTODataObject") Then
		XMLString = XDTOContactsInXML(Data);
		ContactInformationType = ValueFromXMLString(XSLT_ContactInformationTypeByXMLString(XMLString));
	Else
		
		If TypeOf(Data) = Type("Structure") Then
			FieldsValues = ?(Data.Property("FieldsValues"), Data.FieldsValues, "");;
			Comment = ?(Data.Property("Comment"), Data.Comment, "");
			
			If Data.Property("ContactInformationKind") AND Data.ContactInformationKind <> Undefined Then
				ContactInformationType = ContactInformationManagementInternalCached.ContactInformationKindType(Data.ContactInformationKind);
			EndIf;
			
		ElsIf TypeOf(Data) = Type("String") Then
			FieldsValues = Data;
		EndIf;
		
		If ContactsManagerClientServer.IsJSONContactInformation(FieldsValues) Then
			XMLString = ContactsFromJSONToXML(FieldsValues, ContactInformationType);
			ContactInformationType = ValueFromXMLString(XSLT_ContactInformationTypeByXMLString(XMLString));
		ElsIf IsXMLString(FieldsValues) Then
			XMLString = FieldsValues;
			ContactInformationType = ValueFromXMLString(XSLT_ContactInformationTypeByXMLString(XMLString));
		ElsIf TypeOf(FieldsValues) = Type("String") AND ContactInformationType = Undefined Then
			
			// Obsolete format key-value
			If StrFind(Upper(FieldsValues), "STATE=") > 0 Then
				ContactInformationType = Enums.ContactInformationTypes.Address;
			ElsIf StrFind(Upper(FieldsValues), "PHONENUMBER=") > 0 Then
				ContactInformationType = Enums.ContactInformationTypes.Phone;
			ElsIf StrFind(Upper(FieldsValues), "FAXNUMBER=") > 0 Then
				ContactInformationType = Enums.ContactInformationTypes.Fax;
			Else
				ContactInformationType = Enums.ContactInformationTypes.Other;
			EndIf;
			
		EndIf;
	
	EndIf;
	
	If ValueIsFilled(XMLString) Then
		
		If Not IsBlankString(Comment) Then
			ContactsManager.SetContactInformationComment(FieldsValues, Comment);
		EndIf;

		Return New Structure("XMLData, ContactInformationType", XMLString, ContactInformationType);
	EndIf;
	
	// Parsing by FieldsValues, ContactInformationKind, Presentation.
	FieldValueType = TypeOf(FieldsValues);
	If FieldValueType = Type("String") Then
		// Text contained in key-value pairs
		XMLStructureString = XSLT_KeyValueStringToStructure(FieldsValues)
		
	ElsIf FieldValueType = Type("ValueList") Then
		// Value list
		XMLStructureString = XSLT_ValueListToStructure( ValueToXMLString(FieldsValues) );
		
	ElsIf FieldValueType = Type("Map") Then
		// Map
		XMLStructureString = XSLT_MapToStructure( ValueToXMLString(FieldsValues) );
		
	ElsIf FieldValueType = Type("XDTODataObject") Then
		// Expecting a structure
		If FieldsValues.Content.Country = Undefined Then
			FieldsValues.Content.Country = "";
		EndIf;
		If FieldsValues.Content.Content = Undefined Then
			FieldsValues.Content.Content = "";
		EndIf;
		
		XMLStructureString = ValueToXMLString(FieldsValues);
	Else
		// Expecting a structure
		XMLStructureString = ValueToXMLString(FieldsValues);
		
	EndIf;
	
	Result = New Structure("ContactInformationType, XMLData", ContactInformationType);
	
	AllTypes = Enums.ContactInformationTypes;
	If ContactInformationType = AllTypes.Address Then
		Result.XMLData = XSLT_StructureToAddress(XMLStructureString, Data.Presentation, Comment);
		
	ElsIf ContactInformationType = AllTypes.EmailAddress Then
		Result.XMLData = XSLT_StructureToEmailAddress(XMLStructureString, Data.Presentation, Comment);
		
	ElsIf ContactInformationType = AllTypes.WebPage Then
		Result.XMLData = XSLT_StructureToWebPage(XMLStructureString, Data.Presentation, Comment);
		
	ElsIf ContactInformationType = AllTypes.Phone Then
		Result.XMLData = XSLT_StructureToPhone(XMLStructureString, Data.Presentation, Comment);
		
	ElsIf ContactInformationType = AllTypes.Fax Then
		Result.XMLData = XSLT_StructureToFax(XMLStructureString, Data.Presentation, Comment);
		
	ElsIf ContactInformationType = AllTypes.Other Then
		Result.XMLData = XSLT_StructureToOther(XMLStructureString, Data.Presentation, Comment);
		
	ElsIf ContactInformationType = AllTypes.Skype Then
		Result.XMLData = XSLT_StructureToOther(XMLStructureString, Data.Presentation, Comment);
		
	Else
		Raise NStr("ru = 'Ошибка параметров преобразования, не определен тип контактной информации'; en = 'Transformation parameter error, contact information type not specified'; pl = 'Błąd parametru transformacji, nie określono typu informacji kontaktowych';es_ES = 'Error del parámetro de transformación, el tipo de la información de contacto no está especificado';es_CO = 'Error del parámetro de transformación, el tipo de la información de contacto no está especificado';tr = 'Dönüşüm parametreleri hatası, iletişim bilgileri türü belirlenmedi';it = 'Errore del parametro di trasformazione, il tipo di nformazioni di contatto non è specificato';de = 'Transformationsparameterfehler, Kontaktinformationstyp nicht angegeben'");
		
	EndIf;
	
	Return Result;
EndFunction
	
// Converts the XML format to the JSON format
//
Function ContactInformationToJSONStructure(ContactInformation, Val Type = Undefined, Presentation = "", UpdateIDs = True) Export
	
	If Type <> Undefined AND TypeOf(Type) <> Type("EnumRef.ContactInformationTypes") Then
		Type = ContactInformationManagementInternalCached.ContactInformationKindType(Type);
	EndIf;
	
	If Type = Undefined Then
		If TypeOf(ContactInformation) = Type("String") Then
			
			If IsXMLString(ContactInformation) Then
				Type = ContactInformationType(ContactInformation);
			EndIf;
			
		ElsIf TypeOf(ContactInformation) = Type("XDTODataObject") Then
			
			TypeFound = ?(ContactInformation.Content = Undefined, Undefined, ContactInformation.Content.Type());
			Type = MapXDTOToContactsTypes(TypeFound);
			
		EndIf;
	EndIf;
	
	If Metadata.CommonModules.Find("AddressManager") <> Undefined AND Type = Enums.ContactInformationTypes.Address Then
		
		ModuleAddressManager = Common.CommonModule("AddressManager");
		Return ModuleAddressManager.ContactInformationToJSONStructure(ContactInformation, Type, Presentation, UpdateIDs);
		
	EndIf;
	
	Result = ContactsManagerClientServer.NewContactInformationDetails(Type);
	
	CountryDescription = "";
	Format9Commas = False;
	AddressItems = New Map;
	
	If TypeOf(ContactInformation) = Type("String") Then
		If ContactsManagerClientServer.IsJSONContactInformation(ContactInformation) Then
			Return JSONStringToStructure(ContactInformation);
		ElsIf ContactsManagerClientServer.IsXMLContactInformation(ContactInformation) Then
			ConversionResult = New Structure;
			XDTOContactInformation = ContactsFromXML(ContactInformation, Type, ConversionResult, Presentation);
		Else
			If StrOccurrenceCount(ContactInformation, ",") = 9 Then
				Format9Commas  = True;
				Result.Value = ContactInformation
			Else
				XDTOContactInformation      = ContactsFromXML(ContactInformation, Type,, Presentation);
			EndIf;
		EndIf;
	ElsIf TypeOf(ContactInformation) = Type("Structure") Then
		
		FieldsMap = New Map();
		FieldsMap.Insert("Presentation", "value");
		FieldsMap.Insert("Comment",   "comment");
		
		If Type = Enums.ContactInformationTypes.Phone Then
			
			FieldsMap.Insert("CountryCode",     "countryCode");
			FieldsMap.Insert("CityCode",     "areaCode");
			FieldsMap.Insert("PhoneNumber", "number");
			FieldsMap.Insert("Extension",    "extNumber");
			
		EndIf;
		
		For each ContactInformationField In ContactInformation Do
			FieldName = FieldsMap.Get(ContactInformationField.Key);
			If FieldName <> Undefined Then
				Result[FieldName] = ContactInformationField.Value;
			EndIf;
		EndDo;
		
		Return Result;
		
	Else
		XDTOContactInformation = ContactInformation;
		Type = Enums.ContactInformationTypes.Address;
	EndIf;
	
	Result.Value   = String(XDTOContactInformation.Presentation);
	Result.Comment = String(XDTOContactInformation.Comment);
	
	If Type <> Enums.ContactInformationTypes.Address AND Type <> Enums.ContactInformationTypes.Phone Then
		Return Result;
	EndIf;
	
	If NOT Format9Commas Then
		
		Namespace = ContactsManagerClientServer.Namespace();
		Composition = XDTOContactInformation.Content;
		
		If Composition = Undefined Then
			Return Result;
		EndIf;
		
		XDTODataType = Composition.Type();
		
		If XDTODataType = XDTOFactory.Type(Namespace, "Address") Then
			
			Result.Insert("Country", String(Composition.Country));
			Country = Catalogs.WorldCountries.FindByDescription(Composition.Country, True);
			CountryDescription = Country.Description;
			Result.Insert("CountryCode", TrimAll(Country.Code));
			
		ElsIf
			
			XDTODataType = XDTOFactory.Type(ContactsManagerClientServer.Namespace(), "PhoneNumber")
			Or XDTODataType = XDTOFactory.Type(ContactsManagerClientServer.Namespace(), "FaxNumber") Then
			
			Result.CountryCode = Composition.CountryCode;
			Result.AreaCode    = Composition.CityCode;
			Result.Number      = Composition.Number;
			Result.ExtNumber   = Composition.Extension;
			
		EndIf;
		
	EndIf;
	
	Return Result;
	
EndFunction

Function MapXDTOToContactsTypes(TypeFound) Export
	
	Namespace = ContactsManagerClientServer.Namespace();
	
	MapTypes = New Map;
	MapTypes.Insert(XDTOFactory.Type(Namespace, "Address"), Enums.ContactInformationTypes.Address);
	MapTypes.Insert(XDTOFactory.Type(Namespace, "Email"), Enums.ContactInformationTypes.EmailAddress);
	MapTypes.Insert(XDTOFactory.Type(Namespace, "Website"), Enums.ContactInformationTypes.WebPage);
	MapTypes.Insert(XDTOFactory.Type(Namespace, "PhoneNumber"), Enums.ContactInformationTypes.Phone);
	MapTypes.Insert(XDTOFactory.Type(Namespace, "FaxNumber"), Enums.ContactInformationTypes.Fax);
	MapTypes.Insert(XDTOFactory.Type(Namespace, "Skype"), Enums.ContactInformationTypes.Skype);
	MapTypes.Insert(XDTOFactory.Type(Namespace, "Other"), Enums.ContactInformationTypes.Other);
	
	Return MapTypes[TypeFound];

EndFunction

#EndRegion

#Region PrivateForWorkingWithXSLT

// Compares two XML strings.
// Only strings and attributes are compared; space characters, CDATA, and so on, are ignored.  Comparison is performed in order.
//
// Parameters:
//    Text1 - String - an XML string.
//    Text2 - String - an XML string.
//
// Returns:
//    String - a serialized ValueTable (http://v8.1c.ru/8.1/data/core) that contains three columns:
//       * Path - String - a path to the difference.
//       * Value1 - String - a value in XML from the Text1 parameter.
//       * Value2 - String - a value in XML from the Text2 parameter.
//
Function XSLT_ValueTableDifferencesXML(Text1, Text2)
	
	Converter = XSLTransform_ValueTableDifferencesXML();
	
	Builder = New TextDocument;
	Builder.AddLine("<dn><f>");
	Builder.AddLine( XSLT_DeleteDescriptionXML(Text1) );
	Builder.AddLine("</f><s>");
	Builder.AddLine( XSLT_DeleteDescriptionXML(Text2) );
	Builder.AddLine("</s></dn>");
	
	Return Converter.TransformFromString(Builder.GetText());
	
EndFunction

// Converts a text with the Key = Value pair separated by line breaks (see the address format) into XML.
// If duplicate keys are encountered, all of them are included in the output but only the last one 
// is used during deserialization due to platform serialization logic.
//
// Parameters:
//    Text - String - Key = Value pairs.
//
// Returns:
//     String - serialized structure XML.
//
Function XSLT_KeyValueStringToStructure(Val Text) 
	
	Converter = XSLTransform_KeyValueStringToStructure();
	Return Converter.TransformFromString(XSLT_ParameterStringNode(Text));
	
EndFunction

// Converts a value list into structure. Transforms a presentation to the key.
//
// Parameters:
//    Text - String - a serialized value list.
//
// Returns:
//    String - a conversion result.
//
Function XSLT_ValueListToStructure(Text)
	
	Converter = XSLTransform_ValueListToStructure();
	Return Converter.TransformFromString(Text);
	
EndFunction

// Converts mapping to structure. Converts a key to key, a value to value.
//
// Parameters:
//    Text - String - serialized mapping.
//
// Returns:
//    String - a conversion result.
//
Function XSLT_MapToStructure(Text)
	
	Converter = XSLTransform_MapToStructure();
	Return Converter.TransformFromString(Text);
	
EndFunction

// Analyzes Path-Value1-Value2 table for the specified contact information kind.
//
// Parameters:
//    Text - String - an XML string with ValueTable received from the XML comparison result.
//    ContactInformationType - EnumRef.ContactInformationTypes - a value from the contact information types enumeration.
//
// Returns:
//    String - a serialized table containing values of different fields.
//
Function XSLT_ContactsXMLDifferenceInterpretation(Val Text, Val ContactInformationType) 
	
	Converter = XSLTransform_ContactInformationXMLDifferenceInterpretation(
		ContactInformationType);
	Return Converter.TransformFromString(Text);
	
EndFunction

// Converts a structure to contact information XML.
//
// Parameters:
//    Text - String - a serialized structure.
//    Presentation - String - an optional presentation. Used only if there is no presentation field 
//                             in the structure.
//    Comment - String - an optional comment. Used only if there is no comment field in the structure.
//
// Returns:
//    String - contact information XML.
//
Function XSLT_StructureToAddress(Val Text, Val Presentation = Undefined, Val Comment = Undefined)
	
	Converter = XSLTransform_XSLTransform();
	Return XSLT_PresentationAndCommentControl(
		Converter.TransformFromString(Text),
		Presentation, Comment);
		
EndFunction

// Converts a structure to contact information XML.
//
// Parameters:
//    Text - String - a serialized structure.
//    Presentation - String - an optional presentation. Used only if there is no presentation field 
//                             in the structure.
//    Comment - String - an optional comment. Used only if there is no comment field in the structure.
//
// Returns:
//    String - contact information XML.
//
Function XSLT_StructureToEmailAddress(Val Text, Val Presentation = Undefined, Val Comment = Undefined)
	
	Converter = XSLTransform_StructureToEmailAddress();
	Return XSLT_PresentationAndCommentControl(
		XSLT_SimpleTypeStringValueControl(Converter.TransformFromString(Text), Presentation), 
		Presentation, Comment);
		
EndFunction

// Converts a structure to contact information XML.
//
// Parameters:
//    Text - String - a serialized structure.
//    Presentation - String - an optional presentation. Used only if there is no presentation field 
//                             in the structure.
//    Comment - String - an optional comment. Used only if there is no comment field in the structure.
//
// Returns:
//    String - contact information XML.
//
Function XSLT_StructureToWebPage(Val Text, Val Presentation = Undefined, Val Comment = Undefined)
	Converter = XSLTransform_StructureToWebPage();
	
	Return XSLT_PresentationAndCommentControl(
		XSLT_SimpleTypeStringValueControl( Converter.TransformFromString(Text), Presentation),
		Presentation, Comment);
		
EndFunction

// Converts a structure to contact information XML.
//
// Parameters:
//    Text - String - a serialized structure.
//    Presentation - String - an optional presentation. Used only if there is no presentation field 
//                             in the structure.
//    Comment - String - an optional comment. Used only if there is no comment field in the structure.
//
// Returns:
//    String - contact information XML.
//
Function XSLT_StructureToPhone(Val Text, Val Presentation = Undefined, Val Comment = Undefined)
	Converter = XSLTransform_StructureToPhone();
	Return XSLT_PresentationAndCommentControl(
		Converter.TransformFromString(Text),
		Presentation, Comment);
EndFunction

// Converts a structure to contact information XML.
//
// Parameters:
//    Text - String - a serialized structure.
//    Presentation - String - an optional presentation. Used only if there is no presentation field 
//                             in the structure.
//    Comment - String - an optional comment. Used only if there is no comment field in the structure.
//
// Returns:
//    String - contact information XML.
//
Function XSLT_StructureToFax(Val Text, Val Presentation = Undefined, Val Comment = Undefined)
	
	Converter = XSLTransform_StructureToFax();
	Return XSLT_PresentationAndCommentControl(
		Converter.TransformFromString(Text),
		Presentation, Comment);
		
EndFunction

// Converts a structure to contact information XML.
//
// Parameters:
//    Text - String - a serialized structure.
//    Presentation - String - an optional presentation. Used only if there is no presentation field 
//                             in the structure.
//    Comment - String - an optional comment. Used only if there is no comment field in the structure.
//
// Returns:
//    String - contact information XML.
//
Function XSLT_StructureToOther(Val Text, Val Presentation = Undefined, Val Comment = Undefined)
	
	Converter = XSLTransform_StructureToOther();
	Return XSLT_PresentationAndCommentControl(
		XSLT_SimpleTypeStringValueControl( Converter.TransformFromString(Text), Presentation),
		Presentation, Comment);
		
EndFunction

// Sets a presentation and a comment in contact information if they are not filled in.
//
// Parameters:
//    Text - String - a serialized structure.
//    Presentation - String - an optional presentation. Used only if there is no presentation field 
//                             in the structure.
//    Comment - String - an optional comment. Used only if there is no comment field in the structure.
//
// Returns:
//    String - contact information XML.
//
Function XSLT_PresentationAndCommentControl(Val Text, Val Presentation = Undefined, Val Comment = Undefined)
	
	If Presentation = Undefined AND Comment = Undefined Then
		Return Text;
	EndIf;
	
	XSLT_Text = New TextDocument;
	XSLT_Text.AddLine("
		|<xsl:stylesheet version=""1.0"" xmlns:xsl=""http://www.w3.org/1999/XSL/Transform""
		|  xmlns:tns=""http://www.v8.1c.ru/ssl/contactinfo""
		|  xmlns=""http://www.v8.1c.ru/ssl/contactinfo"" 
		|>
		|  <xsl:output method=""xml"" omit-xml-declaration=""yes"" indent=""yes"" encoding=""utf-8""/>
		|
		|  <xsl:template match=""node() | @*"">
		|    <xsl:copy>
		|      <xsl:apply-templates select=""node() | @*"" />
		|    </xsl:copy>
		|  </xsl:template>
		|");
		
	If Presentation <> Undefined Then
		XSLT_Text.AddLine("
		|  <xsl:template match=""tns:ContactInformation/@Presentation"">
		|    <xsl:attribute name=""Presentation"">
		|      <xsl:choose>
		|        <xsl:when test="".=''"">" + NormalizedStringXML(Presentation) + "</xsl:when>
		|        <xsl:otherwise>
		|          <xsl:value-of select="".""/>
		|        </xsl:otherwise>
		|      </xsl:choose>
		|    </xsl:attribute>
		|  </xsl:template>
		|");
	EndIf;
	
	If Comment <> Undefined Then
		XSLT_Text.AddLine("
		|  <xsl:template match=""tns:ContactInformation/tns:Comment"">
		|    <xsl:element name=""Comment"">
		|      <xsl:choose>
		|        <xsl:when test="".=''"">" + NormalizedStringXML(Comment) + "</xsl:when>
		|        <xsl:otherwise>
		|          <xsl:value-of select="".""/>
		|        </xsl:otherwise>
		|      </xsl:choose>
		|    </xsl:element>
		|  </xsl:template>
		|");
	EndIf;
		XSLT_Text.AddLine("
		|</xsl:stylesheet>
		|");
		
	Converter = New XSLTransform;
	Converter.LoadXSLStylesheetFromString(XSLT_Text.GetText());
	
	Return Converter.TransformFromString(Text);
EndFunction

// Sets Composition.Value in contact information to the passed presentation.
// If Presentation is undefined, no action is performed. Otherwise, checks whether it is empty.
// Composition. If it is empty and the Composition.Value attribute is empty, insert a presentation value into the composition.
//
// Parameters:
//    Text - String - contact information XML.
//    Presentation - String - a presentation to be set.
//
// Returns:
//    String - contact information XML.
//
Function XSLT_SimpleTypeStringValueControl(Val Text, Val Presentation)
	
	If Presentation = Undefined Then
		Return Text;
	EndIf;
	
	Converter = New XSLTransform;
	Converter.LoadXSLStylesheetFromString("
		|<xsl:stylesheet version=""1.0"" xmlns:xsl=""http://www.w3.org/1999/XSL/Transform""
		|  xmlns:tns=""http://www.v8.1c.ru/ssl/contactinfo""
		|>
		|  <xsl:output method=""xml"" omit-xml-declaration=""yes"" indent=""yes"" encoding=""utf-8""/>
		|  
		|  <xsl:template match=""node() | @*"">
		|    <xsl:copy>
		|      <xsl:apply-templates select=""node() | @*"" />
		|    </xsl:copy>
		|  </xsl:template>
		|  
		|  <xsl:template match=""tns:ContactInformation/tns:Content/@Value"">
		|    <xsl:attribute name=""Value"">
		|      <xsl:choose>
		|        <xsl:when test="".=''"">" + NormalizedStringXML(Presentation) + "</xsl:when>
		|        <xsl:otherwise>
		|          <xsl:value-of select="".""/>
		|        </xsl:otherwise>
		|      </xsl:choose>
		|    </xsl:attribute>
		|  </xsl:template>
		|
		|</xsl:stylesheet>
		|");
	
	Return Converter.TransformFromString(Text);
EndFunction

// Returns an XML fragment to be inserted to an XML string, in <Node>String<Node> format.
//
// Parameters:
//    Text - String - inserting to XML.
//    ItemName - String - an external node name (optional).
//
// Returns:
//    String - a resulting XML.
//
Function XSLT_ParameterStringNode(Val Text, Val ItemName = "ExternalParamNode")
	
	// Writing an XML to mask special characters.
	Record = New XMLWriter;
	Record.SetString();
	Record.WriteStartElement(ItemName);
	Record.WriteText(Text);
	Record.WriteEndElement();
	Return Record.Close();
	
EndFunction

// Returns an XML string without <?xml...> description to be inserted into another XML string.
//
// Parameters:
//    Text - String - a source XML string.
//
// Returns:
//    String - a resulting XML.
//
Function XSLT_DeleteDescriptionXML(Val Text)
	
	Converter = XSLTransform_DeleteDetailsXML();
	Return Converter.TransformFromString(TrimL(Text));
	
EndFunction

// Converts an XML text of contact information to the type enumeration.
//
// Parameters:
//    Text - String - a source XML string.
//
// Returns:
//    String - a serialized value of the ContactsTypes enumeration.
//
Function XSLT_ContactInformationTypeByXMLString(Val Text)
	
	Converter = XSLTransformation_ContactInformationTypeByXMLString();
	Return Converter.TransformFromString(TrimL(Text));
	
EndFunction

//  Returns a flag indicating whether a text is in XML format.
//
//  Parameters:
//      Text - String - a text being checked.
//
// Returns:
//      Boolean - the result of the check.
//
Function IsXMLString(Text)
	
	Return TypeOf(Text) = Type("String") AND Left(TrimL(Text),1) = "<";
	
EndFunction

// Deserializer of types registered with the platform.
Function ValueFromXMLString(Val Text)
	
	XMLReader = New XMLReader;
	XMLReader.SetString(Text);
	Return XDTOSerializer.ReadXML(XMLReader);
	
EndFunction

// Serializer of types registered with the platform.
Function ValueToXMLString(Val Value)
	
	XMLWriter = New XMLWriter;
	XMLWriter.SetString(New XMLWriterSettings(, , False, False, ""));
	XDTOSerializer.WriteXML(XMLWriter, Value, XMLTypeAssignment.Explicit);
	// Platform serializer allows writing line breaks to attribute values.
	Return StrReplace(XMLWriter.Close(), Chars.LF, "&#10;");
	
EndFunction

// Intended for processing attributes containing line breaks.
//
// Parameters:
//     Text - String - an XML string to be modified.
//
// Returns:
//     String - a normalized string.
//
Function MultilineXMLString(Val Text)
	
	Return StrReplace(Text, Chars.LF, "&#10;");
	
EndFunction

// Prepares a string to include in the XML text, removing the special characters.
//
// Parameters:
//     Text - String - an XML string to be modified.
//
// Returns:
//     String - a normalized string.
//
Function NormalizedStringXML(Val Text)
	
	Result = StrReplace(Text,     """", "&quot;");
	Result = StrReplace(Result, "&",  "&amp;");
	Result = StrReplace(Result, "'",  "&apos;");
	Result = StrReplace(Result, "<",  "&lt;");
	Result = StrReplace(Result, ">",  "&gt;");
	Return MultilineXMLString(Result);
	
EndFunction

// Initialization of converters

// Conversion to compare two XML strings.
//
// Returns:
//     XSLTransform - a prepared object.
//
Function XSLTransform_ValueTableDifferencesXML()
	Converter = New XSLTransform;
	
	// The namespace must be empty.
	Converter.LoadXSLStylesheetFromString("
		|<xsl:stylesheet version=""1.0""
		|  xmlns:xsl=""http://www.w3.org/1999/XSL/Transform""
		|  xmlns:xsi=""http://www.w3.org/2001/XMLSchema-instance""
		|  xmlns:xs=""http://www.w3.org/2001/XMLSchema""
		|
		|  xmlns:str=""http://exslt.org/strings""
		|  xmlns:exsl=""http://exslt.org/common""
		|
		|  extension-element-prefixes=""str exsl""
		|>
		|<xsl:output method=""xml"" omit-xml-declaration=""yes"" indent=""yes"" encoding=""utf-8""/>
		|" + XSLT_StringFunctionTemplates() + "
		|" + XSLT_XPathFunctionTemplates() + "
		|
		|  <!-- parce tree elements to xpath-value -->
		|  <xsl:template match=""node()"" mode=""action"">
		|    
		|    <xsl:variable name=""text"">
		|      <xsl:call-template name=""str-trim-all"">
		|        <xsl:with-param name=""str"" select=""text()"" />
		|      </xsl:call-template>
		|    </xsl:variable>
		|
		|    <xsl:if test=""$text!=''"">
		|      <xsl:element name=""item"">
		|        <xsl:attribute name=""path"">
		|          <xsl:variable name=""tmp-path"">
		|            <xsl:call-template name=""build-path"" />
		|          </xsl:variable>
		|          <xsl:value-of select=""substring($tmp-path, 6)"" /> <!-- pass '/dn/f' or '/dn/s' -->
		|        </xsl:attribute>
		|        <xsl:attribute name=""value"">
		|          <xsl:value-of select=""text()"" />
		|        </xsl:attribute>
		|      </xsl:element>
		|    </xsl:if>
		|
		|    <xsl:apply-templates select=""@* | node()"" mode=""action""/>
		|  </xsl:template>
		|
		|  <!-- parce tree attributes to xpath-value -->
		|  <xsl:template match=""@*"" mode=""action"">
		|    <xsl:element name=""item"">
		|      <xsl:attribute name=""path"">
		|          <xsl:variable name=""tmp-path"">
		|            <xsl:call-template name=""build-path"" />
		|          </xsl:variable>
		|          <xsl:value-of select=""substring($tmp-path, 6)"" /> <!-- pass '/dn/f' or '/dn/s' -->
		|      </xsl:attribute>
		|      <xsl:attribute name=""value"">
		|        <xsl:value-of select=""."" />
		|      </xsl:attribute>
		|    </xsl:element>
		|  </xsl:template>
		|
		|  <!-- main -->
		|  <xsl:variable name=""dummy"">
		|    <xsl:element name=""first"">
		|      <xsl:apply-templates select=""/dn/f"" mode=""action"" />
		|    </xsl:element> 
		|    <xsl:element name=""second"">
		|      <xsl:apply-templates select=""/dn/s"" mode=""action"" />
		|    </xsl:element>
		|  </xsl:variable>
		|  <xsl:variable name=""dummy-nodeset"" select=""exsl:node-set($dummy)"" />
		|  <xsl:variable name=""first-items"" select=""$dummy-nodeset/first/item"" />
		|  <xsl:variable name=""second-items"" select=""$dummy-nodeset/second/item"" />
		|
		|  <xsl:template match=""/"">
		|    
		|    <!-- first vs second -->
		|    <xsl:variable name=""first-second"">
		|      <xsl:for-each select=""$first-items"">
		|        <xsl:call-template name=""compare"">
		|          <xsl:with-param name=""check"" select=""$second-items"" />
		|        </xsl:call-template>
		|      </xsl:for-each>
		|    </xsl:variable>
		|    <xsl:variable name=""first-second-nodeset"" select=""exsl:node-set($first-second)"" />
		|
		|    <!-- second vs first without doubles -->
		|    <xsl:variable name=""doubles"" select=""$first-second-nodeset/item"" />
		|    <xsl:variable name=""second-first"">
		|      <xsl:for-each select=""$second-items"">
		|        <xsl:call-template name=""compare"">
		|          <xsl:with-param name=""check"" select=""$first-items"" />
		|          <xsl:with-param name=""doubles"" select=""$doubles"" />
		|        </xsl:call-template>
		|      </xsl:for-each>
		|    </xsl:variable>
		|      
		|    <!-- result -->
		|    <ValueTable xmlns=""http://v8.1c.ru/8.1/data/core"" xmlns:xs=""http://www.w3.org/2001/XMLSchema"" xsi:type=""ValueTable"">
		|      <column>
		|        <Name xsi:type=""xs:string"">Path</Name>
		|        <ValueType>
		|           <Type>xs:string</Type>
		|           <StringQualifiers><Length>0</Length><AllowedLength>Variable</AllowedLength></StringQualifiers>
		|        </ValueType>
		|      </column>
		|      <column>
		|        <Name xsi:type=""xs:string"">Value1</Name>
		|        <ValueType>
		|           <Type>xs:string</Type>
		|           <StringQualifiers><Length>0</Length><AllowedLength>Variable</AllowedLength></StringQualifiers>
		|        </ValueType>
		|      </column>
		|      <column>
		|        <Name xsi:type=""xs:string"">Value2</Name>
		|        <ValueType>
		|           <Type>xs:string</Type>
		|           <StringQualifiers><Length>0</Length><AllowedLength>Variable</AllowedLength></StringQualifiers>
		|        </ValueType>
		|      </column>
		|
		|      <xsl:for-each select=""$first-second-nodeset/item | exsl:node-set($second-first)/item"">
		|        <xsl:element name=""row"">
		|           <xsl:element name=""Value"">
		|             <xsl:value-of select=""@path""/>
		|           </xsl:element>
		|           <xsl:element name=""Value"">
		|             <xsl:value-of select=""@value1""/>
		|           </xsl:element>
		|           <xsl:element name=""Value"">
		|             <xsl:value-of select=""@value2""/>
		|           </xsl:element>
		|        </xsl:element>
		|      </xsl:for-each>
		|
		|    </ValueTable>
		|
		|  </xsl:template>
		|  <!-- /main -->
		|
		|  <!-- compare sub -->
		|  <xsl:template name=""compare"">
		|    <xsl:param name=""check"" />
		|    <xsl:param name=""doubles"" select=""/.."" />
		|    
		|    <xsl:variable name=""path""  select=""@path""/>
		|    <xsl:variable name=""value"" select=""@value""/>
		|    <xsl:variable name=""diff""  select=""$check[@path=$path]""/>
		|    <xsl:choose>
		|      <xsl:when test=""count($diff)=0"">
		|        <xsl:if test=""count($doubles[@path=$path and @value1='' and @value2=$value])=0"">
		|          <xsl:element name=""item"">
		|            <xsl:attribute name=""path"">   <xsl:value-of select=""$path""/> </xsl:attribute>
		|            <xsl:attribute name=""value1""> <xsl:value-of select=""$value""/> </xsl:attribute>
		|            <xsl:attribute name=""value2"" />
		|          </xsl:element>
		|        </xsl:if>
		|      </xsl:when>
		|      <xsl:otherwise>
		|
		|        <xsl:for-each select=""$diff[@value!=$value]"">
		|            <xsl:variable name=""diff-value"" select=""@value""/>
		|            <xsl:if test=""count($doubles[@path=$path and @value1=$diff-value and @value2=$value])=0"">
		|              <xsl:element name=""item"">
		|                <xsl:attribute name=""path"">   <xsl:value-of select=""$path""/>  </xsl:attribute>
		|                <xsl:attribute name=""value1""> <xsl:value-of select=""$value""/> </xsl:attribute>
		|                <xsl:attribute name=""value2""> <xsl:value-of select=""@value""/> </xsl:attribute>
		|              </xsl:element>
		|            </xsl:if>
		|        </xsl:for-each>
		|      </xsl:otherwise>
		|    </xsl:choose>
		|  </xsl:template>
		|  
		|</xsl:stylesheet>
		|");
		
	Return Converter;
EndFunction

// Converts a text with the Key = Value pairs separated by line breaks (see the address format) to XML.
// If duplicate keys are encountered, all of them are included in the output but only the last one 
// is used during deserialization due to platform serialization logic.
//
// Returns:
//     XSLTransform - a prepared object.
//
Function XSLTransform_KeyValueStringToStructure()
	Converter = New XSLTransform;
	Converter.LoadXSLStylesheetFromString("
		|<xsl:stylesheet version=""1.0""
		|  xmlns:xsl=""http://www.w3.org/1999/XSL/Transform""
		|  xmlns:str=""http://exslt.org/strings""
		|  extension-element-prefixes=""str""
		|>
		|<xsl:output method=""xml"" omit-xml-declaration=""yes"" indent=""yes"" encoding=""utf-8""/>
		|" + XSLT_StringFunctionTemplates() + "
		|
		|  <xsl:template match=""ExternalParamNode"">
		|
		|    <xsl:variable name=""source"">
		|      <xsl:call-template name=""str-replace-all"">
		|        <xsl:with-param name=""str"" select=""."" />
		|        <xsl:with-param name=""search-for"" select=""'&#10;&#09;'"" />
		|        <xsl:with-param name=""replace-by"" select=""'&#13;'"" />
		|      </xsl:call-template>
		|    </xsl:variable>
		|
		|    <Structure xmlns=""http://v8.1c.ru/8.1/data/core"" xmlns:xs=""http://www.w3.org/2001/XMLSchema"" xmlns:xsi=""http://www.w3.org/2001/XMLSchema-instance"" xsi:type=""Structure"">
		|
		|     <xsl:for-each select=""str:tokenize($source, '&#10;')"" >
		|       <xsl:if test=""contains(., '=')"">
		|
		|         <xsl:element name=""Property"">
		|           <xsl:attribute name=""name"" >
		|             <xsl:call-template name=""str-trim-all"">
		|               <xsl:with-param name=""str"" select=""substring-before(., '=')"" />
		|             </xsl:call-template>
		|           </xsl:attribute>
		|
		|           <Value xsi:type=""xs:string"">
		|             <xsl:call-template name=""str-replace-all"">
		|               <xsl:with-param name=""str"" select=""substring-after(., '=')"" />
		|               <xsl:with-param name=""search-for"" select=""'&#13;'"" />
		|               <xsl:with-param name=""replace-by"" select=""'&#10;'"" />
		|             </xsl:call-template>
		|           </Value>
		|
		|         </xsl:element>
		|
		|       </xsl:if>
		|     </xsl:for-each>
		|
		|    </Structure>
		|
		|  </xsl:template>
		|
		|</xsl:stylesheet>
		|");

	Return Converter;
EndFunction

// Conversion for a value list into the structure. Transforms a presentation to the key.
//
// Returns:
//     XSLTransform - a prepared object.
//
Function XSLTransform_ValueListToStructure()
	Converter = New XSLTransform;
	Converter.LoadXSLStylesheetFromString("
		|<xsl:stylesheet version=""1.0"" xmlns:xsl=""http://www.w3.org/1999/XSL/Transform""
		|  xmlns:xsi=""http://www.w3.org/2001/XMLSchema-instance""
		|  xmlns:tns=""http://v8.1c.ru/8.1/data/core""
		|  xmlns=""http://v8.1c.ru/8.1/data/core""
		|>
		|<xsl:output method=""xml"" omit-xml-declaration=""yes"" indent=""yes"" encoding=""utf-8""/>
		|" + XSLT_StringFunctionTemplates() + "
		|
		|  <xsl:template match=""/"">
		|    <Structure xmlns=""http://v8.1c.ru/8.1/data/core"" xmlns:xs=""http://www.w3.org/2001/XMLSchema"" xmlns:xsi=""http://www.w3.org/2001/XMLSchema-instance"" xsi:type=""Structure"">
		|      <xsl:apply-templates select=""//tns:ValueListType/tns:item"" />
		|    </Structure >
		|  </xsl:template>
		|
		|  <xsl:template match=""//tns:ValueListType/tns:item"">
		|    <xsl:element name=""Property"">
		|      <xsl:attribute name=""name"">
		|        <xsl:call-template name=""str-trim-all"">
		|          <xsl:with-param name=""str"" select=""tns:presentation"" />
		|        </xsl:call-template>
		|      </xsl:attribute>
		|
		|      <xsl:element name=""Value"">
		|        <xsl:attribute name=""xsi:type"">
		|          <xsl:value-of select=""tns:value/@xsi:type""/>  
		|        </xsl:attribute>
		|        <xsl:value-of select=""tns:value""/>  
		|      </xsl:element>
		|
		|    </xsl:element>
		|</xsl:template>
		|
		|</xsl:stylesheet>
		|");
	Return Converter;
EndFunction

// Conversion of a mapping into the structure. Converts a key to key, a value to value.
//
// Returns:
//     XSLTransform - a prepared object.
//
Function XSLTransform_MapToStructure()
	Converter = New XSLTransform;
	Converter.LoadXSLStylesheetFromString("
		|<xsl:stylesheet version=""1.0"" xmlns:xsl=""http://www.w3.org/1999/XSL/Transform""
		|  xmlns:xsi=""http://www.w3.org/2001/XMLSchema-instance""
		|  xmlns:tns=""http://v8.1c.ru/8.1/data/core""
		|  xmlns=""http://v8.1c.ru/8.1/data/core""
		|>
		|<xsl:output method=""xml"" omit-xml-declaration=""yes"" indent=""yes"" encoding=""utf-8""/>
		|" + XSLT_StringFunctionTemplates() + "
		|
		|  <xsl:template match=""/"">
		|    <Structure xmlns=""http://v8.1c.ru/8.1/data/core"" xmlns:xs=""http://www.w3.org/2001/XMLSchema"" xmlns:xsi=""http://www.w3.org/2001/XMLSchema-instance"" xsi:type=""Structure"">
		|      <xsl:apply-templates select=""//tns:Map/tns:pair"" />
		|    </Structure >
		|  </xsl:template>
		|  
		|  <xsl:template match=""//tns:Map/tns:pair"">
		|  <xsl:element name=""Property"">
		|    <xsl:attribute name=""name"">
		|      <xsl:call-template name=""str-trim-all"">
		|        <xsl:with-param name=""str"" select=""tns:Key"" />
		|      </xsl:call-template>
		|    </xsl:attribute>
		|  
		|    <xsl:element name=""Value"">
		|      <xsl:attribute name=""xsi:type"">
		|        <xsl:value-of select=""tns:Value/@xsi:type""/>  
		|      </xsl:attribute>
		|        <xsl:value-of select=""tns:Value""/>  
		|      </xsl:element>
		|  
		|    </xsl:element>
		|  </xsl:template>
		|
		|</xsl:stylesheet>
		|");
	Return Converter;
EndFunction

// Removes the <?xml...> details to be included into another XML.
//
// Returns:
//     XSLTransform - a prepared object.
//
Function XSLTransform_DeleteDetailsXML()
	Converter = New XSLTransform;
	Converter.LoadXSLStylesheetFromString("
		|<xsl:stylesheet version=""1.0"" xmlns:xsl=""http://www.w3.org/1999/XSL/Transform"">
		|<xsl:output method=""xml"" omit-xml-declaration=""yes"" indent=""yes"" encoding=""utf-8""/>
		|  <xsl:template match=""node() | @*"">
		|    <xsl:copy>
		|      <xsl:apply-templates select=""node() | @*"" />
		|    </xsl:copy>
		|  </xsl:template>
		|</xsl:stylesheet>
		|");
	Return Converter;
EndFunction

// Converts an XML string containing contact information (see the ContactInformation XDTO package) into enumeration
// ContactInformationType.
//
// Returns:
//     XSLTransform - a prepared object.
//
Function XSLTransformation_ContactInformationTypeByXMLString()
	Converter = New XSLTransform;
	Converter.LoadXSLStylesheetFromString("
		|<xsl:stylesheet version=""1.0"" xmlns:xsl=""http://www.w3.org/1999/XSL/Transform""
		|  xmlns:xsi=""http://www.w3.org/2001/XMLSchema-instance""
		|  xmlns:ci=""http://www.v8.1c.ru/ssl/contactinfo""
		|>
		|  <xsl:output method=""xml"" omit-xml-declaration=""yes"" indent=""yes"" encoding=""utf-8""/>
		|
		|  <xsl:template match=""/"">
		|    <EnumRef.ContactInformationTypes xmlns=""http://v8.1c.ru/8.1/data/enterprise/current-config"" xmlns:xs=""http://www.w3.org/2001/XMLSchema"" xmlns:xsi=""http://www.w3.org/2001/XMLSchema-instance"" xsi:type=""EnumRef.ContactInformationTypes"">
		|      <xsl:call-template name=""enum-by-type"" >
		|        <xsl:with-param name=""type"" select=""ci:ContactInformation/ci:Content/@xsi:type"" />
		|      </xsl:call-template>
		|    </EnumRef.ContactInformationTypes>
		|  </xsl:template>
		|
		|  <xsl:template name=""enum-by-type"">
		|    <xsl:param name=""type"" />
		|    <xsl:choose>
		|      <xsl:when test=""$type='Address'"">
		|        <xsl:text>Address</xsl:text>
		|      </xsl:when>
		|      <xsl:when test=""$type='PhoneNumber'"">
		|        <xsl:text>Phone</xsl:text>
		|      </xsl:when>
		|      <xsl:when test=""$type='FaxNumber'"">
		|        <xsl:text>Fax</xsl:text>
		|      </xsl:when>
		|      <xsl:when test=""$type='Email'"">
		|        <xsl:text>EmailAddress</xsl:text>
		|      </xsl:when>
		|      <xsl:when test=""$type='Website'"">
		|        <xsl:text>WebPage</xsl:text>
		|      </xsl:when>
		|      <xsl:when test=""$type='Other'"">
		|        <xsl:text>Other</xsl:text>
		|      </xsl:when>
		|    </xsl:choose>
		|  </xsl:template>
		|
		|</xsl:stylesheet>
		|");
	Return Converter;
EndFunction

// Converts an XML difference table depending on the contact information type.
//
// Parameters:
//    ContactInformationType - EnumRef.ContactInformationTypes - the enumeration name or value.
//
// Returns:
//     XSLTransform - a prepared object.
//
Function XSLTransform_ContactInformationXMLDifferenceInterpretation(Val ContactInformationType)
	
	If TypeOf(ContactInformationType) <> Type("String") Then
		ContactInformationType = ContactInformationType.Metadata().Name;
	EndIf;
	
	Converter = New XSLTransform;
	Converter.LoadXSLStylesheetFromString("
		|<xsl:stylesheet version=""1.0"" xmlns:xsl=""http://www.w3.org/1999/XSL/Transform""
		|  xmlns:xsi=""http://www.w3.org/2001/XMLSchema-instance""
		|  xmlns:ci=""http://www.v8.1c.ru/ssl/contactinfo""
		|>
		|<xsl:output method=""xml"" omit-xml-declaration=""yes"" indent=""yes"" encoding=""utf-8""/>
		|  <xsl:param name=""target-type"" select=""'" + ContactInformationType + "'""/>
		|
		|  <xsl:template match=""/"">
		|    <xsl:choose>
		|      <xsl:when test=""$target-type='Address'"">
		|         <xsl:apply-templates select=""."" mode=""action-address""/>
		|      </xsl:when>
		|      <xsl:otherwise>
		|         <xsl:apply-templates select=""."" mode=""action-copy""/>
		|      </xsl:otherwise>
		|    </xsl:choose>
		|  </xsl:template>
		|
		|  <xsl:template match=""node() | @*"" mode=""action-copy"">
		|    <xsl:copy>
		|      <xsl:apply-templates select=""node() | @*"" mode=""action-copy""/>
		|    </xsl:copy>
		|  </xsl:template>
		|
		|  <xsl:template match=""node() | @*"" mode=""action-address"">
		|    <xsl:copy>
		|      <xsl:apply-templates select=""node() | @*"" mode=""action-address""/>
		|    </xsl:copy>
		|  </xsl:template>
		|
		|</xsl:stylesheet>
		|");
	Return Converter;
EndFunction

// Returns an XSL converter to convert a structure to XML contact information. 
//
// Returns:
//     XSLTransform - a prepared object.
//
Function XSLTransform_XSLTransform()
	
	If Metadata.CommonModules.Find("AddressManager") <> Undefined Then
		ModuleAddressManager = Common.CommonModule("AddressManager");
		AdditionalConversionRules = ModuleAddressManager.AdditionalConversionRules();
	EndIf;
	
	Converter = New XSLTransform;
	Converter.LoadXSLStylesheetFromString("
		|<xsl:stylesheet version=""1.0"" xmlns:xsl=""http://www.w3.org/1999/XSL/Transform""
		|  xmlns:xsi=""http://www.w3.org/2001/XMLSchema-instance""
		|  xmlns:xs=""http://www.w3.org/2001/XMLSchema""
		|  xmlns:tns=""http://v8.1c.ru/8.1/data/core""
		|  xmlns=""http://www.v8.1c.ru/ssl/contactinfo"" 
		|
		|  xmlns:data=""http://www.v8.1c.ru/ssl/contactinfo""
		|
		|  xmlns:exsl=""http://exslt.org/common""
		|  extension-element-prefixes=""exsl""
		|  exclude-result-prefixes=""data tns""
		|>
		|<xsl:output method=""xml"" omit-xml-declaration=""yes"" indent=""yes"" encoding=""utf-8""/>
		|  " + XSLT_StringFunctionTemplates() + "
		|  
		|  <xsl:variable name=""local-country"">RUSSIA</xsl:variable>
		|
		|  <xsl:variable name=""presentation"" select=""tns:Structure/tns:Property[@name='Presentation']/tns:Value/text()"" />
		|  
		|  <xsl:template match=""/"">
		|    <ContactInformation>
		|
		|      <xsl:attribute name=""Presentation"">
		|        <xsl:value-of select=""$presentation""/>
		|      </xsl:attribute> 
		|      <xsl:element name=""Comment"">
		|       <xsl:value-of select=""tns:Structure/tns:Property[@name='Comment']/tns:Value/text()""/>
		|      </xsl:element>
		|
		|      <xsl:element name=""Content"">
		|        <xsl:attribute name=""xsi:type"">Address</xsl:attribute>
		|        <xsl:variable name=""country"" select=""tns:Structure/tns:Property[@name='Country']/tns:Value/text()""></xsl:variable>
		|        <xsl:variable name=""country-upper"">
		|          <xsl:call-template name=""str-upper"">
		|            <xsl:with-param name=""str"" select=""$country"" />
		|          </xsl:call-template>
		|        </xsl:variable>
		|
		|        <xsl:attribute name=""Country"">
		|          <xsl:choose>
		|            <xsl:when test=""0=count($country)"">
		|              <xsl:value-of select=""$local-country"" />
		|            </xsl:when>
		|            <xsl:otherwise>
		|              <xsl:value-of select=""$country"" />
		|            </xsl:otherwise> 
		|          </xsl:choose>
		|        </xsl:attribute>
		|
		|        <xsl:choose>
		|          <xsl:when test=""0=count($country)"">
		|            <xsl:apply-templates select=""/"" mode=""domestic"" />
		|          </xsl:when>
		|          <xsl:when test=""$country-upper=$local-country"">
		|            <xsl:apply-templates select=""/"" mode=""domestic"" />
		|          </xsl:when>
		|          <xsl:otherwise>
		|            <xsl:apply-templates select=""/"" mode=""foreign"" />
		|          </xsl:otherwise> 
		|        </xsl:choose>
		|
		|      </xsl:element>
		|    </ContactInformation>
		|  </xsl:template>
		|  
		|  <xsl:template match=""/"" mode=""foreign"">
		|    <xsl:element name=""Content"">
		|      <xsl:attribute name=""xsi:type"">xs:string</xsl:attribute>
		|
		|      <xsl:variable name=""value"" select=""tns:Structure/tns:Property[@name='Value']/tns:Value/text()"" />        
		|      <xsl:choose>
		|        <xsl:when test=""0=count($value)"">
		|          <xsl:value-of select=""$presentation"" />
		|        </xsl:when>
		|        <xsl:otherwise>
		|          <xsl:value-of select=""$value"" />
		|        </xsl:otherwise> 
		|      </xsl:choose>
		|    
		|    </xsl:element>
		|  </xsl:template>
		|" + AdditionalConversionRules);
		
		Return Converter;
EndFunction

// Converts a serialized structure into contact information in XML format.
//
// Returns:
//     XSLTransform - a prepared object.
//
Function XSLTransform_StructureToEmailAddress()
	Return XSLTransform_StructureToStringComposition("Email");
EndFunction

// Converts a serialized structure into contact information in XML format.
//
// Returns:
//     XSLTransform - a prepared object.
//
Function XSLTransform_StructureToWebPage()
	Return XSLTransform_StructureToStringComposition("Website");
EndFunction

// Converts a serialized structure into contact information in XML format.
//
Function XSLTransform_StructureToPhone()
	Return XSLTransform_StructureToPhoneFax("PhoneNumber");
EndFunction

// Converts a serialized structure into contact information in XML format.
//
// Returns:
//     XSLTransform - a prepared object.
//
Function XSLTransform_StructureToFax()
	Return XSLTransform_StructureToPhoneFax("FaxNumber");
EndFunction

// Converts a serialized structure into contact information in XML format.
//
// Returns:
//     XSLTransform - a prepared object.
//
Function XSLTransform_StructureToOther()
	Return XSLTransform_StructureToStringComposition("Other");
EndFunction

// General conversion of a serialized structure into contact information in XML format of a simple type.
//
// Returns:
//     XSLTransform - a prepared object.
//
Function XSLTransform_StructureToStringComposition(Val XDTOTypeName)
	Converter = New XSLTransform;
	Converter.LoadXSLStylesheetFromString("
		|<xsl:stylesheet version=""1.0"" xmlns:xsl=""http://www.w3.org/1999/XSL/Transform""
		|  xmlns:xsi=""http://www.w3.org/2001/XMLSchema-instance""
		|  xmlns:tns=""http://v8.1c.ru/8.1/data/core""
		|  xmlns=""http://www.v8.1c.ru/ssl/contactinfo"" 
		|>
		|<xsl:output method=""xml"" omit-xml-declaration=""yes"" indent=""yes"" encoding=""utf-8""/>
		|
		|<xsl:template match=""/"">
		|  
		|  <xsl:element name=""ContactInformation"">
		|  
		|  <xsl:attribute name=""Presentation"">
		|    <xsl:value-of select=""tns:Structure/tns:Property[@name='Presentation']/tns:Value/text()""/>
		|  </xsl:attribute> 
		|  <xsl:element name=""Comment"">
		|    <xsl:value-of select=""tns:Structure/tns:Property[@name='Comment']/tns:Value/text()""/>
		|  </xsl:element>
		|  
		|  <xsl:element name=""Content"">
		|    <xsl:attribute name=""xsi:type"">" + XDTOTypeName + "</xsl:attribute>
		|    <xsl:attribute name=""Value"">
		|    <xsl:choose>
		|      <xsl:when test=""0=count(tns:Structure/tns:Property[@name='Value'])"">
		|      <xsl:value-of select=""tns:Structure/tns:Property[@name='Presentation']/tns:Value/text()""/>
		|      </xsl:when>
		|      <xsl:otherwise>
		|      <xsl:value-of select=""tns:Structure/tns:Property[@name='Value']/tns:Value/text()""/>
		|      </xsl:otherwise>
		|    </xsl:choose>
		|    </xsl:attribute>
		|    
		|  </xsl:element>
		|  </xsl:element>
		|  
		|</xsl:template>
		|</xsl:stylesheet>
		|");
	Return Converter;
EndFunction

// General conversion for a phone and a fax.
//
// Returns:
//     XSLTransform - a prepared object.
//
Function XSLTransform_StructureToPhoneFax(Val XDTOTypeName)
	Converter = New XSLTransform;
	Converter.LoadXSLStylesheetFromString("
		|<xsl:stylesheet version=""1.0"" xmlns:xsl=""http://www.w3.org/1999/XSL/Transform""
		|  xmlns:xsi=""http://www.w3.org/2001/XMLSchema-instance""
		|  xmlns:tns=""http://v8.1c.ru/8.1/data/core""
		|  xmlns=""http://www.v8.1c.ru/ssl/contactinfo"" 
		|>
		|<xsl:output method=""xml"" omit-xml-declaration=""yes"" indent=""yes"" encoding=""utf-8""/>
		|  <xsl:template match=""/"">
		|
		|    <xsl:element name=""ContactInformation"">
		|
		|      <xsl:attribute name=""Presentation"">
		|        <xsl:value-of select=""tns:Structure/tns:Property[@name='Presentation']/tns:Value/text()""/>
		|      </xsl:attribute> 
		|      <xsl:element name=""Comment"">
		|        <xsl:value-of select=""tns:Structure/tns:Property[@name='Comment']/tns:Value/text()""/>
		|      </xsl:element>
		|      <xsl:element name=""Content"">
		|        <xsl:attribute name=""xsi:type"">" + XDTOTypeName + "</xsl:attribute>
		|
		|        <xsl:attribute name=""CountryCode"">
		|          <xsl:value-of select=""tns:Structure/tns:Property[@name='CountryCode']/tns:Value/text()""/>
		|        </xsl:attribute> 
		|        <xsl:attribute name=""CityCode"">
		|          <xsl:value-of select=""tns:Structure/tns:Property[@name='CityCode']/tns:Value/text()""/>
		|        </xsl:attribute> 
		|        <xsl:attribute name=""Number"">
		|          <xsl:value-of select=""tns:Structure/tns:Property[@name='PhoneNumber']/tns:Value/text()""/>
		|        </xsl:attribute> 
		|        <xsl:attribute name=""Extension"">
		|          <xsl:value-of select=""tns:Structure/tns:Property[@name='Extension']/tns:Value/text()""/>
		|        </xsl:attribute> 
		|
		|      </xsl:element>
		|    </xsl:element>
		|
		|  </xsl:template>
		|</xsl:stylesheet>
		|");
	Return Converter;
EndFunction

// XSL fragment including string processing procedures.
//
// Returns:
//     String - an XML fragment to be used in the conversion.
//
Function XSLT_StringFunctionTemplates()
	Return "
		|<!-- string functions -->
		|
		|  <xsl:template name=""str-trim-left"">
		|    <xsl:param name=""str"" />
		|    <xsl:variable name=""head"" select=""substring($str, 1, 1)""/>
		|    <xsl:variable name=""tail"" select=""substring($str, 2)""/>
		|    <xsl:choose>
		|      <xsl:when test=""(string-length($str) > 0) and (string-length(normalize-space($head)) = 0)"">
		|        <xsl:call-template name=""str-trim-left"">
		|          <xsl:with-param name=""str"" select=""$tail""/>
		|        </xsl:call-template>
		|      </xsl:when>
		|      <xsl:otherwise>
		|        <xsl:value-of select=""$str""/>
		|      </xsl:otherwise>
		|    </xsl:choose>
		|  </xsl:template>
		|
		|  <xsl:template name=""str-trim-right"">
		|    <xsl:param name=""str"" />
		|    <xsl:variable name=""head"" select=""substring($str, 1, string-length($str) - 1)""/>
		|    <xsl:variable name=""tail"" select=""substring($str, string-length($str))""/>
		|    <xsl:choose>
		|      <xsl:when test=""(string-length($str) > 0) and (string-length(normalize-space($tail)) = 0)"">
		|        <xsl:call-template name=""str-trim-right"">
		|          <xsl:with-param name=""str"" select=""$head""/>
		|        </xsl:call-template>
		|      </xsl:when>
		|      <xsl:otherwise>
		|        <xsl:value-of select=""$str""/>
		|      </xsl:otherwise>
		|    </xsl:choose>
		|  </xsl:template>
		|
		|  <xsl:template name=""str-trim-all"">
		|    <xsl:param name=""str"" />
		|      <xsl:call-template name=""str-trim-right"">
		|        <xsl:with-param name=""str"">
		|          <xsl:call-template name=""str-trim-left"">
		|            <xsl:with-param name=""str"" select=""$str""/>
		|          </xsl:call-template>
		|      </xsl:with-param>
		|    </xsl:call-template>
		|  </xsl:template>
		|
		|  <xsl:template name=""str-replace-all"">
		|    <xsl:param name=""str"" />
		|    <xsl:param name=""search-for"" />
		|    <xsl:param name=""replace-by"" />
		|    <xsl:choose>
		|      <xsl:when test=""contains($str, $search-for)"">
		|        <xsl:value-of select=""substring-before($str, $search-for)"" />
		|        <xsl:value-of select=""$replace-by"" />
		|        <xsl:call-template name=""str-replace-all"">
		|          <xsl:with-param name=""str"" select=""substring-after($str, $search-for)"" />
		|          <xsl:with-param name=""search-for"" select=""$search-for"" />
		|          <xsl:with-param name=""replace-by"" select=""$replace-by"" />
		|        </xsl:call-template>
		|      </xsl:when>
		|      <xsl:otherwise>
		|        <xsl:value-of select=""$str"" />
		|      </xsl:otherwise>
		|    </xsl:choose>
		|  </xsl:template>
		|
		|  <xsl:param name=""alpha-low"" select=""'abcdefghijklmnopqrstuvwxyz'"" />
		|  <xsl:param name=""alpha-up""  select=""'ABCDEFGHIJKLMNOPQRSTUVWXYZ'"" />
		|
		|  <xsl:template name=""str-upper"">
		|    <xsl:param name=""str"" />
		|    <xsl:value-of select=""translate($str, $alpha-low, $alpha-up)""/>
		|  </xsl:template>
		|
		|  <xsl:template name=""str-lower"">
		|    <xsl:param name=""str"" />
		|    <xsl:value-of select=""translate($str, alpha-up, $alpha-low)"" />
		|  </xsl:template>
		|
		|<!-- /string functions -->
		|";
EndFunction

// XSL fragment including xpath management procedures.
//
// Returns:
//     String - an XML fragment to be used in the conversion.
//
Function XSLT_XPathFunctionTemplates()
	Return "
		|<!-- path functions -->
		|
		|  <xsl:template name=""build-path"">
		|  <xsl:variable name=""node"" select="".""/>
		|
		|    <xsl:for-each select=""$node | $node/ancestor-or-self::node()[..]"">
		|      <xsl:choose>
		|        <!-- element -->
		|        <xsl:when test=""self::*"">
		|            <xsl:value-of select=""'/'""/>
		|            <xsl:value-of select=""name()""/>
		|            <xsl:variable name=""thisPosition"" select=""count(preceding-sibling::*[name(current()) = name()])""/>
		|            <xsl:variable name=""numFollowing"" select=""count(following-sibling::*[name(current()) = name()])""/>
		|            <xsl:if test=""$thisPosition + $numFollowing > 0"">
		|              <xsl:value-of select=""concat('[', $thisPosition +1, ']')""/>
		|            </xsl:if>
		|        </xsl:when>
		|        <xsl:otherwise>
		|          <!-- not element -->
		|          <xsl:choose>
		|            <!-- attribute -->
		|            <xsl:when test=""count(. | ../@*) = count(../@*)"">
		|                <xsl:value-of select=""'/'""/>
		|                <xsl:value-of select=""concat('@',name())""/>
		|            </xsl:when>
		|            <!-- text- -->
		|            <xsl:when test=""self::text()"">
		|                <xsl:value-of select=""'/'""/>
		|                <xsl:value-of select=""'text()'""/>
		|                <xsl:variable name=""thisPosition"" select=""count(preceding-sibling::text())""/>
		|                <xsl:variable name=""numFollowing"" select=""count(following-sibling::text())""/>
		|                <xsl:if test=""$thisPosition + $numFollowing > 0""> 
		|                  <xsl:value-of select=""concat('[', $thisPosition +1, ']')""/>
		|                </xsl:if>
		|            </xsl:when>
		|            <!-- processing instruction -->
		|            <xsl:when test=""self::processing-instruction()"">
		|                <xsl:value-of select=""'/'""/>
		|                <xsl:value-of select=""'processing-instruction()'""/>
		|                <xsl:variable name=""thisPosition"" select=""count(preceding-sibling::processing-instruction())""/>
		|                <xsl:variable name=""numFollowing"" select=""count(following-sibling::processing-instruction())""/>
		|                <xsl:if test=""$thisPosition + $numFollowing > 0"">
		|                  <xsl:value-of select=""concat('[', $thisPosition +1, ']')""/>
		|                </xsl:if>
		|            </xsl:when>
		|            <!-- comment -->
		|            <xsl:when test=""self::comment()"">
		|                <xsl:value-of select=""'/'""/>
		|                <xsl:value-of select=""'comment()'""/>
		|                <xsl:variable name=""thisPosition"" select=""count(preceding-sibling::comment())""/>
		|                <xsl:variable name=""numFollowing"" select=""count(following-sibling::comment())""/>
		|                <xsl:if test=""$thisPosition + $numFollowing > 0"">
		|                  <xsl:value-of select=""concat('[', $thisPosition +1, ']')""/>
		|                </xsl:if>
		|            </xsl:when>
		|            <!-- namespace -->
		|            <xsl:when test=""count(. | ../namespace::*) = count(../namespace::*)"">
		|              <xsl:variable name=""ap"">'</xsl:variable>
		|              <xsl:value-of select=""'/'""/>
		|                <xsl:value-of select=""concat('namespace::*','[local-name() = ', $ap, local-name(), $ap, ']')""/>
		|            </xsl:when>
		|          </xsl:choose>
		|        </xsl:otherwise>
		|      </xsl:choose>
		|    </xsl:for-each>
		|
		|  </xsl:template>
		|
		|<!-- /path functions -->
		|";
EndFunction

#EndRegion

// Area JSON conversion and other types: structure, XML, and so on.

// Conversion

Function ToJSONStringStructure(Value) Export
	
	JSONWriter = New JSONWriter;
	JSONWriter.SetString();
	
	For each StructureItem In Value Do
		If IsBlankString(StructureItem.Value) AND StructureItem.Value <> "" Then
			// Converting undefined, NULL, and insignificant characters to an empty string.
			Value[StructureItem.Key] = "";
		ElsIf TypeOf(StructureItem.Value) = Type("Array") Then
			
			For each ConstructionsAndPremises In StructureItem.Value Do
				If IsBlankString(ConstructionsAndPremises.Number) AND ConstructionsAndPremises.Number <> "" Then
					ConstructionsAndPremises.Number = "";
				EndIf;
			EndDo;
			
		EndIf;
	EndDo;
	
	WriteJSON(JSONWriter, Value,, "ContactInformationFieldsAdjustment", ContactsManagerInternal);
	
	Return JSONWriter.Close();
	
EndFunction

Function ContactInformationFieldsAdjustment(Property, Value, TransformerFunctionAdditionalParameters, Cancel) Export
	
	If TypeOf(Value) = Type("UUID") Then
		Return String(Value);
	EndIf;
	
EndFunction

Function JSONStringToStructure(Value) Export
	
	JSONReader = New JSONReader;
	JSONReader.SetString(Value);
	
	Result = ReadJSON(JSONReader,,,, "RestoreContactInformationFields", ContactsManagerInternal);
	
	JSONReader.Close();
	
	Return Result;
	
EndFunction

Function RestoreContactInformationFields(Property, Value, TransformerFunctionAdditionalParameters) Export
	
	If StrEndsWith(Upper(Property), "ID") AND StrLen(Value) = 36 Then
		Return New UUID(Value);
	EndIf;
	
EndFunction

Function ContactsFromJSONToXML(Val ContactInformation, ExpectedType = Undefined) Export
	
	If ContactsManagerClientServer.IsJSONContactInformation(ContactInformation) Then
		ContactInformation = JSONStringToStructure(ContactInformation);
	EndIf;
	
	If ExpectedType = Undefined Then
		
		If TypeOf(ContactInformation) = Type("Structure") AND ContactInformation.Property("Type") Then
			
			ExpectedType = Enums.ContactInformationTypes[ContactInformation.Type];
			
		ElsIf ContactsManagerClientServer.IsXMLContactInformation(ContactInformation) Then
			ContactInformationXML = TransformContactInformationXML(ContactInformation);
			ExpectedType = ContactInformationXML.ContactInformationType;
		Else
			ErrorText = NStr("ru='Ошибка конвертации контактной информации из формата JSON в XML.'; en = 'An error occurred while converting contact information from JSON to XML.'; pl = 'Błąd konwersji informacji kontaktowych z formatu JSON w XML.';es_ES = 'Error de conversión de la información de contacto del formato JSON a XML.';es_CO = 'Error de conversión de la información de contacto del formato JSON a XML.';tr = 'İletişim bilgilerini JSON biçiminden XML''YE dönüştürme hatası.';it = 'Errore della conversione dell''informazione di contatto dal formato JSON in XML.';de = 'Fehler bei der Konvertierung von Kontaktinformationen vom JSON- in das XML-Format.'");
			WriteLogEvent(InfobaseUpdate.EventLogEvent(), 
				EventLogLevel.Error,,,
				ErrorText + Chars.LF + String(ContactInformation));
			Raise NStr("ru='Не удалось определить тип контактной информации. Подробнее см. в журнале регистрации.'; en = 'Cannot determine contact information type. For more information, see the event log.'; pl = 'Nie udało się określić rodzaj informacji kontaktowych. Więcej informacji można znaleźć w dzienniku rejestracji.';es_ES = 'No se ha podido determinar el tipo de la información de contacto. Véase más en el registro de eventos.';es_CO = 'No se ha podido determinar el tipo de la información de contacto. Véase más en el registro de eventos.';tr = 'İletişim bilgileri türü belirlenemedi. Daha fazla bilgi için olay günlüğüne bakın.';it = 'Impossibile determinare il tipo di informazione di contatto. Per più informazioni, visualizzare il registro degli eventi.';de = 'Die Art der Kontaktinformationen kann nicht ermittelt werden. Einzelheiten finden Sie im Ereignisprotokoll.'");
		EndIf;
		
	EndIf;
	
	Namespace = ContactsManagerClientServer.Namespace();

	IsNew = IsBlankString(ContactInformation);
	Presentation = "";
	
	Result = XDTOFactory.Create(XDTOFactory.Type(Namespace, "ContactInformation"));
	
	// Parsing
	If ExpectedType = Enums.ContactInformationTypes.Address Then
		If IsNew Then
			Result.Content = XDTOFactory.Create(XDTOFactory.Type(Namespace, "Address"));
		Else
			Result = ConvertAddressFromJSONToXML(ContactInformation, Presentation, ExpectedType);
		EndIf;
		
	ElsIf ExpectedType = Enums.ContactInformationTypes.Phone Then
		If IsNew Then
			Result.Content = XDTOFactory.Create(XDTOFactory.Type(Namespace, "PhoneNumber"));
		Else
			Result = ConvertPhoneFaxFromJSONToXML(ContactInformation, Presentation, ExpectedType)
		EndIf;
		
	ElsIf ExpectedType = Enums.ContactInformationTypes.Fax Then
		If IsNew Then
			Result.Content = XDTOFactory.Create(XDTOFactory.Type(Namespace, "FaxNumber"));
		Else
			Result = ConvertPhoneFaxFromJSONToXML(ContactInformation, Presentation, ExpectedType)
		EndIf;
		
	ElsIf ExpectedType = Enums.ContactInformationTypes.EmailAddress Then
		If IsNew Then
			Result.Content = XDTOFactory.Create(XDTOFactory.Type(Namespace, "Email"));
		Else
			Result = ConvertOtherContactsFromJSONToXML(ContactInformation, Presentation, ExpectedType)
		EndIf;
	ElsIf ExpectedType = Enums.ContactInformationTypes.Skype Then
		If IsNew Then
			Result.Content = XDTOFactory.Create(XDTOFactory.Type(Namespace, "Skype"));
		Else
			Result = ConvertOtherContactsFromJSONToXML(ContactInformation, Presentation, ExpectedType)
		EndIf;
	ElsIf ExpectedType = Enums.ContactInformationTypes.WebPage Then
		If IsNew Then
			Result.Content = XDTOFactory.Create(XDTOFactory.Type(Namespace, "Website"));
		Else
			Result = ConvertOtherContactsFromJSONToXML(ContactInformation, Presentation, ExpectedType)
		EndIf;
		
	ElsIf ExpectedType = Enums.ContactInformationTypes.Other Then
		If IsNew Then
			Result.Content = XDTOFactory.Create(XDTOFactory.Type(Namespace, "Other"));
		Else
			Result = ConvertOtherContactsFromJSONToXML(ContactInformation, Presentation, ExpectedType)
		EndIf;
		
	Else
		ErrorText = NStr("ru = 'Сведения о типе контактной информации %1 были повреждены или некорректно заполнены,
								|т.к. обязательное поле тип не заполнено.'; 
								|en = 'Information on contact information type %1 was damaged or filled in incorrectly
								|as the required ""Type"" field is not filled in.'; 
								|pl = 'Informacje o rodzaju informacji kontaktowych %1 zostały uszkodzone lub niepoprawnie wypełnione,
								|ponieważ obowiązkowe pole rodzaj nie zostało wypełnione.';
								|es_ES = 'Los detalles del tipo la información de contacto %1 han sido dañados o rellenados incorrectamente,
								|porque el campo obligatorio tipo no está rellenado.';
								|es_CO = 'Los detalles del tipo la información de contacto %1 han sido dañados o rellenados incorrectamente,
								|porque el campo obligatorio tipo no está rellenado.';
								|tr = 'İletişim bilgileri türü hakkındaki %1bilgileri bozuk veya yanlış doldurulmuştur, 
								|çünkü zorunlu tür alanı doldurulmamıştır.';
								|it = 'Le informazioni sulla tipologia di informazioni di contatto %1 è stata danneggiata o compilata non correttamente
								|dato che il campo richiesto ""Tipo"" non è stato compilato.';
								|de = 'Informationen über die Art der Kontaktinformationen %1 wurden beschädigt oder falsch ausgefüllt,
								|da das Pflichtfeld nicht ausgefüllt ist.'");
		ErrorText =  StringFunctionsClientServer.SubstituteParametersToString(ErrorText, ?(ValueIsFilled(ExpectedType), """" + TrimAll(ExpectedType) + """", ""));
	EndIf;
	
	Return XDTOContactsInXML(Result);
	
EndFunction

// Internal, for serialization purposes.
Function ConvertAddressFromJSONToXML(Val FieldsValues, Val Presentation, Val ExpectedType = Undefined)
	
	If Metadata.CommonModules.Find("AddressManager") <> Undefined Then
		ModuleAddressManager = Common.CommonModule("AddressManager");
		Return ModuleAddressManager.ConvertAddressFromJSONToXML(FieldsValues, Presentation, ExpectedType);
	EndIf;
	
	// Old format with line separator and equality.
	Namespace = ContactsManagerClientServer.Namespace();
	
	Result = XDTOFactory.Create(XDTOFactory.Type(Namespace, "ContactInformation"));
	Result.Content      = XDTOFactory.Create(XDTOFactory.Type(Namespace, "Address"));
	
	// Common composition
	Address = Result.Content;
	
	PresentationField      = "";
	
	For Each ListItem In FieldsValues Do
		
		If IsBlankString(ListItem.Value) Then
			Continue;
		EndIf;
		
		FieldName = Upper(ListItem.Key);
		
		If FieldName = "COMMENT" Then
			Comment = TrimAll(ListItem.Value);
			If ValueIsFilled(Comment) Then
				Result.Comment = Comment;
			EndIf;
			
		ElsIf FieldName = "COUNTRY" Then
			Address.Country = String(ListItem.Value);
			
		ElsIf FieldName = "VALUE" Then
			PresentationField = TrimAll(ListItem.Value);
			
		EndIf;
		
	EndDo;
	
	// Presentation with priorities.
	If Not IsBlankString(Presentation) Then
		Result.Presentation = Presentation;
	Else
		Result.Presentation = PresentationField;
	EndIf;
	
	Address.Content = Result.Presentation;
	
	Return Result;
EndFunction

Function ConvertPhoneFaxFromJSONToXML(FieldsValues, Presentation = "", ExpectedType = Undefined)
	
	If ContactsManagerClientServer.IsXMLContactInformation(FieldsValues) Then
		// Common format of contact information.
		Return ContactsFromXML(FieldsValues, ExpectedType);
	EndIf;
	
	Namespace = ContactsManagerClientServer.Namespace();
	
	If ExpectedType = Enums.ContactInformationTypes.Phone Then
		Data = XDTOFactory.Create(XDTOFactory.Type(Namespace, "PhoneNumber"));
		
	ElsIf ExpectedType = Enums.ContactInformationTypes.Fax Then
		Data = XDTOFactory.Create(XDTOFactory.Type(Namespace, "FaxNumber"));
		
	ElsIf ExpectedType = Undefined Then
		// This data is considered to be a phone number
		Data = XDTOFactory.Create(XDTOFactory.Type(Namespace, "PhoneNumber"));
		
	Else
		Raise NStr("ru='Ошибка преобразования контактной информации, ожидается телефон или факс'; en = 'An error occurred when converting contact information. Phone or fax number is expected'; pl = 'Błąd konwersji danych kontaktowych, oczekuję na telefon lub faks';es_ES = 'Ha ocurrido un error al transformar la información de contacto, número de teléfono o fax están esperados';es_CO = 'Ha ocurrido un error al transformar la información de contacto, número de teléfono o fax están esperados';tr = 'İletişim bilgilerinin dönüştürme sırasında bir hata oluştu, telefon veya faks numarası bekleniyor';it = 'Errore di trasformazione dell''informazione di contatto, in attesa del numero di telefono o del fax';de = 'Fehler bei der Konvertierung von Kontaktinformationen, erwartetem Telefon oder Fax'");
	EndIf;
	
	Result = XDTOFactory.Create(XDTOFactory.Type(Namespace, "ContactInformation"));
	Result.Content        = Data;
	
	PresentationField = "";
	For Each FieldValue In FieldsValues Do
		Field = Upper(FieldValue.Key);
		
		If Field = "COUNTRYCODE" Then
			Data.CountryCode = FieldValue.Value;
			
		ElsIf Field = "AREACODE" Then
			Data.CityCode = FieldValue.Value;
			
		ElsIf Field = "NUMBER" Then
			Data.Number = FieldValue.Value;
			
		ElsIf Field = "EXTNUMBER" Then
			Data.Extension = FieldValue.Value;
			
		ElsIf Field = "VALUE" Then
			PresentationField = TrimAll(FieldValue.Value);
			
		ElsIf Field = "COMMENT" Then
			Comment = TrimAll(FieldValue.Value);
			If ValueIsFilled(Comment) Then
				Result.Comment = Comment;
			EndIf;
			
		EndIf;
		
	EndDo;
	
	// Presentation with priorities.
	If Not IsBlankString(Presentation) Then
		Result.Presentation = Presentation;
	ElsIf ValueIsFilled(PresentationField) Then
		Result.Presentation = PresentationField;
	Else
		Result.Presentation = PhonePresentation(Data);
	EndIf;
	
	Return Result;
	
EndFunction

// Converts a string into other XDTO contact information.
//
// Parameters:
//   FieldsValues - String - serialized information, field values.
//   Presentation - String - superiority-based presentation. Used for parsing purposes if FieldsValues is empty.
//   ExpectedType - EnumRef.ContactsType - an optional type for control.
//
// Returns:
//   XDTOObject - contact information.
//
Function ConvertOtherContactsFromJSONToXML(FieldsValues, Val Presentation = "", ExpectedType = Undefined)
	
	If ContactsManagerClientServer.IsXMLContactInformation(FieldsValues) Then
		// Common format of contact information.
		Return ContactsFromXML(FieldsValues, ExpectedType);
	EndIf;
	
	Namespace = ContactsManagerClientServer.Namespace();
	Result = XDTOFactory.Create(XDTOFactory.Type(Namespace, "ContactInformation"));
	
	If IsBlankString(Presentation) AND FieldsValues.Property("Value") AND ValueIsFilled(FieldsValues.Value) Then
		Presentation = FieldsValues.Value;
	EndIf;
	
	Result.Presentation = Presentation;
	
	If ExpectedType = Enums.ContactInformationTypes.EmailAddress Then
		Result.Content = XDTOFactory.Create(XDTOFactory.Type(Namespace, "Email"));
		
	ElsIf ExpectedType = Enums.ContactInformationTypes.WebPage Then
		Result.Content = XDTOFactory.Create(XDTOFactory.Type(Namespace, "Website"));
		
	ElsIf ExpectedType = Enums.ContactInformationTypes.Skype Then
		Result.Content = XDTOFactory.Create(XDTOFactory.Type(Namespace, "Skype"));
		
	ElsIf ExpectedType = Enums.ContactInformationTypes.Other Then
		Result.Content = XDTOFactory.Create(XDTOFactory.Type(Namespace, "Other"));
		
	ElsIf ExpectedType <> Undefined Then
		Raise NStr("ru = 'Ошибка десериализации контактной информации, ожидается другой тип'; en = 'Contact information deserialization error. Another type is expected.'; pl = 'Wystąpił błąd podczas deserializowania informacji kontaktowych, oczekiwany jest inny typ';es_ES = 'Ha ocurrido un error al deserializar la información de contacto, otro tipo está esperado';es_CO = 'Ha ocurrido un error al deserializar la información de contacto, otro tipo está esperado';tr = 'İletişim bilgilerinin seriden paralele çevrilmesi sırasında bir hata oluştu, diğer tür bekleniyor';it = 'Errore della deserializzazione delle informazioni di contatto. Un altro tipo è atteso.';de = 'Beim Deserialisieren der Kontaktinformationen ist ein Fehler aufgetreten, ein anderer Typ wird erwartet'");
		
	EndIf;
	
	Result.Content.Value = Presentation;
	
	Comment = "";
	If FieldsValues.Property("Comment") AND ValueIsFilled(FieldsValues.Comment) Then
		Comment = TrimAll(FieldsValues.Comment);
		If ValueIsFilled(Comment) Then
			Result.Comment = Comment;
		EndIf;
	EndIf;
	
	
	
	Return Result;
	
EndFunction

#EndRegion


