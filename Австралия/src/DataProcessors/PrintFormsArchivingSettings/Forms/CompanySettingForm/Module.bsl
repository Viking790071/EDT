
#Region FormEventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	Var MarkedItems;
	
	Parameters.Property("Company", Company);
	Parameters.Property("DocumentTypesArray", MarkedItems);
	
	If ValueIsFilled(Company) Then
		Items.Company.ReadOnly = True;
	Else
		IsNewSetting = True;
	EndIf;
	
	DriveServer.FillDocumentsTypesList(DocumentTypeList, MarkedItems);
	
EndProcedure

#EndRegion

#Region FormCommandsEventHandlers

&AtClient
Procedure Save(Command)
	
	If ValueIsFilled(Company) Then
		
		If IsNewSetting AND NOT CheckRecordUniqueness(Company) Then
			
			MessageText = StringFunctionsClientServer.SubstituteParametersToString(
				NStr("en = 'Settings for company %1 already exist'; ru = 'В информационной базе уже имеются настройки для организации %1';pl = 'Ustawienia dla firmy %1 już istnieją';es_ES = 'Configuraciones para la empresa %1 ya existen.';es_CO = 'Configuraciones para la empresa %1 ya existen.';tr = '%1 iş yerinin ayarları zaten mevcut';it = 'Le impostazioni per l''azienda %1 già esistono';de = 'Einstellungen zur Firma %1 sind bereits vorhanden'"),
				Company);
			CommonClientServer.MessageToUser(MessageText);
			
			Return;
			
		EndIf;
		
		NewDocumentTypeList = New ValueList;
		
		For Each ListItem In DocumentTypeList Do
			
			If ListItem.Check Then
				NewDocumentTypeList.Add(ListItem.Value, ListItem.Presentation);
			EndIf;
			
		EndDo;
		
		If NewDocumentTypeList.Count() = 0 Then
			CommonClientServer.MessageToUser(NStr("en = 'To save, mark at least one document type'; ru = 'Для сохранения отметьте, как минимум, один тип документов';pl = 'Aby zapisać, zaznacz co najmniej jeden typ dokumentu';es_ES = 'Para guardar, marque al menos un tipo de documento';es_CO = 'Para guardar, marque al menos un tipo de documento';tr = 'Kaydetmek için en az bir belge türünü işaretleyin';it = 'Per salvare, contrassegnate almeno un tipo di documento';de = 'Zum Speichern markieren Sie mindestens eine Dokumentart.'"));
		Else
			ClosingResult = New Structure("Company, DocumentTypeList", Company, NewDocumentTypeList);
			Close(ClosingResult);
		EndIf;
		
	Else
		
		CommonClientServer.MessageToUser(NStr("en = 'Company must be filled in'; ru = 'Поле ""Организация"" должно быть заполнено';pl = 'Pole Firma powinno być wypełnione';es_ES = 'La empresa tiene que estar rellenada';es_CO = 'La empresa tiene que estar rellenada';tr = 'İş yeri doldurulmalıdır';it = 'L''azienda deve essere compilata';de = 'Firma muss ausgefüllt werden'"), , "Company");
		
	EndIf;
	
EndProcedure

#EndRegion

#Region Private

&AtServer
Function CheckRecordUniqueness(CheckCompany)
	
	Result = True;
	
	Query = New Query;
	Query.Text =
	"SELECT TOP 1
	|	TRUE AS VrtField
	|FROM
	|	InformationRegister.PrintFormsArchivingSettings AS PrintFormsArchivingSettings
	|WHERE
	|	PrintFormsArchivingSettings.Company = &Company";
	
	Query.SetParameter("Company", CheckCompany);
	
	If NOT Query.Execute().IsEmpty() Then
		Result = False;
	EndIf;
	
	Return Result;
	
EndFunction

#EndRegion