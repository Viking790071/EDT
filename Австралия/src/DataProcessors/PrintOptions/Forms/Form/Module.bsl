
#Region FormEventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Not Parameters.Property("ID") Then
		
		TextMessage = NStr("en = 'The data processor is not intended for direct usage.'; ru = 'Обработка не предназначена для непосредственного использования.';pl = 'Procesor danych nie jest przeznaczony dla bezpośredniego użycia.';es_ES = 'Procesador de datos no está destinado al uso directo.';es_CO = 'Procesador de datos no está destinado al uso directo.';tr = 'Veri işlemcisi doğrudan kullanıma yönelik değil.';it = 'L''elaboratore dati non è inteso per un uso diretto.';de = 'Der Datenprozessor ist nicht für den direkten Gebrauch bestimmt.'");
		CommonClientServer.MessageToUser(TextMessage,,,,Cancel);
		
		Return;
		
	EndIf;
	
	Object.PrintCommandID = Parameters.ID;
	
	DocumentObject = Parameters.AdditionalParameters.MetadataObject;
	Object.MetadataName = DocumentObject.Metadata().Name;
	
	Object.User = SessionParameters.CurrentUser;
	
	FillAdditionalLanguages();
	
EndProcedure

&AtServer
Procedure OnOpenAtServer()
	
	PrnOptions = PrintManagementServerCallDrive.GetPrintOptionsByUsers(Object.MetadataName, Object.PrintCommandID, Object.User);
	FillPropertyValues(Object, PrnOptions,,"PrintCommandID, User, MetadataName");
	
	StructureOptionsInDocuments	= PrintManagementServerCallDrive.GetStructureOptionsInDocuments(Object.PrintCommandID);
	DocumentInPrintOptionsList	= StructureOptionsInDocuments.DocumentInPrintOptionsList;
	IsCustomColumns				= StructureOptionsInDocuments.CustomColumns;
	
	Items.GroupPrintTypes.Visible		= DocumentInPrintOptionsList;
	Items.GroupUserSettings.Visible		= DocumentInPrintOptionsList;
	Items.GroupCustomColumns.Visible	= IsCustomColumns;
	
	Items.DoNotShowAgain.Visible		= GetFunctionalOption("DisplayPrintOptionsBeforePrinting");
	Constants.UseAdditionalLanguage1.Get();
	
EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	OnOpenAtServer();
EndProcedure

#EndRegion

#Region FormCommandHandlers

&AtClient
Procedure Ok(Command)
	
	PrintParameters = PrintManagementServerCallDrive.NewPrintOptionsStructure();
	FillPropertyValues(PrintParameters, Object);
	
	SaveOptionsByUser();
	
	Close(PrintParameters);
	
EndProcedure

#EndRegion

#Region Private

&AtServer
Procedure SaveOptionsByUser()
	
	SetPrivilegedMode(True);
	
	BeginTransaction();
	Try
		RecordsSet = InformationRegisters.PrintOptionsByUsers.CreateRecordSet();
		RecordsSet.Filter.PrintCommandID.Set(Object.PrintCommandID);
		RecordsSet.Filter.MetadataName.Set(Object.MetadataName);
		RecordsSet.Filter.User.Set(Object.User);
		
		RecordsSet.Read();
		
		If RecordsSet.Count() = 0 Then
			NewRow = RecordsSet.Add();
			FillPropertyValues(NewRow, Object);
		Else
			FillPropertyValues(RecordsSet[0], Object);
		EndIf;
		
		RecordsSet.Write();
		
		CommitTransaction();
	Except
		RollbackTransaction();
		WriteLogEvent(
			Nstr("en = 'Write user print options.'; ru = 'Сохранить пользовательские настройки печати.';pl = 'Zapisz opcje drukowania użytkownika.';es_ES = 'Escribir las opciones de impresión del usuario.';es_CO = 'Escribir las opciones de impresión del usuario.';tr = 'Kullanıcı yazdırma seçeneklerini yazın.';it = 'Registra opzioni di stampa utente';de = 'Benutzerdruckoptionen schreiben'",
			CommonClientServer.DefaultLanguageCode()),
			EventLogLevel.Error,,, DetailErrorDescription(ErrorInfo()));
		
		SetPrivilegedMode(False);
		
		Raise;
	EndTry;
	
EndProcedure    

&AtServer
Procedure FillAdditionalLanguages()
	
	Query = New Query;
	Query.Text = 
	"SELECT
	|	DefaultLanguage.Value AS Language
	|FROM
	|	Constant.DefaultLanguage AS DefaultLanguage
	|
	|UNION ALL
	|
	|SELECT
	|	AdditionalLanguage1.Value
	|FROM
	|	Constant.AdditionalLanguage1 AS AdditionalLanguage1,
	|	Constant.UseAdditionalLanguage1 AS UseAdditionalLanguage1
	|WHERE
	|	UseAdditionalLanguage1.Value
	|
	|UNION ALL
	|
	|SELECT
	|	AdditionalLanguage2.Value
	|FROM
	|	Constant.AdditionalLanguage2 AS AdditionalLanguage2,
	|	Constant.UseAdditionalLanguage2 AS UseAdditionalLanguage2
	|WHERE
	|	UseAdditionalLanguage2.Value
	|
	|UNION ALL
	|
	|SELECT
	|	AdditionalLanguage3.Value
	|FROM
	|	Constant.AdditionalLanguage3 AS AdditionalLanguage3,
	|	Constant.UseAdditionalLanguage3 AS UseAdditionalLanguage3
	|WHERE
	|	UseAdditionalLanguage3.Value
	|
	|UNION ALL
	|
	|SELECT
	|	AdditionalLanguage4.Value
	|FROM
	|	Constant.AdditionalLanguage4 AS AdditionalLanguage4,
	|	Constant.UseAdditionalLanguage4 AS UseAdditionalLanguage4
	|WHERE
	|	UseAdditionalLanguage4.Value";
	
	UsedLanguages = Query.Execute().Unload().UnloadColumn("Language");
	
	For Each LanguageMetadata In Metadata.Languages Do
		
		If UsedLanguages.Find(LanguageMetadata.LanguageCode) <> Undefined Then
			Items.Language.ChoiceList.Add(LanguageMetadata.LanguageCode, LanguageMetadata.Synonym);
		EndIf;
		
	EndDo;
	
	Items.GroupLanguage.Visible = UsedLanguages.Count() > 1;
	
EndProcedure    

#EndRegion