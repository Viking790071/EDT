#Region FormEventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	SetEDIProviderVisible();
	FormManagement();
	
	If NOT Object.Ref.IsEmpty() Then
		SetPrivilegedMode(True);
		PasswordFromSecureStorage = Common.ReadDataFromSecureStorage(Object.Ref, "Password");
		SetPrivilegedMode(False);
		Password = ?(ValueIsFilled(PasswordFromSecureStorage), ThisObject.UUID, "");
	EndIf;
	
EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	
	If Object.Ref.IsEmpty() Then
		OnProviderCompanyChange();
		FillDocumentsForExchange();
	EndIf;
	
EndProcedure

&AtClient
Procedure AfterWrite(WriteParameters)
	
	UsedFilter = New Structure;
	UsedFilter.Insert("Use", True);
	UsedDocuments = Object.DocumentsForExchange.FindRows(UsedFilter);
	If UsedDocuments.Count() = 0 Then
		CommonClientServer.MessageToUser(
			NStr("en = 'Please select documents to exchange.'; ru = 'Выберите документы для обмена.';pl = 'Wybierz dokumenty do wymiany.';es_ES = 'Por favor, seleccione los documentos a intercambiar.';es_CO = 'Por favor, seleccione los documentos a intercambiar.';tr = 'Lütfen değiştirilecek belgeleri seçin.';it = 'Selezionare documenti da scambiare.';de = 'Bitte wählen Sie Dokumente zum Austausch aus.'"),
			,
			"Object.DocumentsForExchange");
	EndIf;
	
EndProcedure

&AtClient
Procedure BeforeWrite(Cancel, WriteParameters)
	
	If Not MessageWasShown Then
		
		CompanyInfo = CompanyInfo(Object.Company);
		
		If Not ValueIsFilled(CompanyInfo.CompanyPostalAddress)Then
			
			MessageToUserText = NStr("en = 'Before you start the exchange, please fill in the legal address in your company’s profile.'; ru = 'Перед началом обмена заполните юридический адрес в профиле организации.';pl = 'Przed rozpoczęciem wymiany, wypełnij adres prawny w profilu twojej firmy.';es_ES = 'Antes de comenzar el intercambio, por favor, rellene el domicilio legal en el perfil de su empresa.';es_CO = 'Antes de comenzar el intercambio, por favor, rellene el domicilio legal en el perfil de su empresa.';tr = 'Değişime başlamadan önce lütfen iş yeri profilinizde yasal adresi doldurun.';it = 'Prima di eseguire lo scambio, indicare l''indirizzo legale nel proprio profilo aziendale.';de = 'Bevor Sie mit dem Austausch beginnen, tragen Sie bitte die Geschäftsadresse im Profil Ihrer Firma ein.'");
			MessageWasShown = True;
			Cancel = True;
			Res = New NotifyDescription("DoAfterCloseMessageBox", ThisObject);
			ShowMessageBox(Res, MessageToUserText);
			
		EndIf;
		
	EndIf;
	
EndProcedure

&AtServer
Procedure OnWriteAtServer(Cancel, CurrentObject, WriteParameters)
	
	If PasswordChanged Then
		SetPrivilegedMode(True);
		Common.WriteDataToSecureStorage(CurrentObject.Ref, Password);
		SetPrivilegedMode(False);
		Password = ?(ValueIsFilled(Password), ThisObject.UUID, "");
		PasswordChanged = False;
	EndIf;
	
EndProcedure

#EndRegion

#Region FormHeaderItemsEventHandlers

&AtClient
Procedure ProviderOnChange(Item)
	
	OnProviderCompanyChange();
	FillDocumentsForExchange();
	
EndProcedure

&AtClient
Procedure CompanyOnChange(Item)
	
	OnProviderCompanyChange();
	
EndProcedure

&AtClient
Procedure PasswordOnChange(Item)
	PasswordChanged = True;
EndProcedure

#EndRegion

#Region FormCommandsEventHandlers

&AtClient
Procedure UncheckAll(Command)
	
	For Each DocumentRow In Object.DocumentsForExchange Do
		
		DocumentRow.Use = False;
		
	EndDo;
	
EndProcedure

&AtClient
Procedure CheckAll(Command)
	
	For Each DocumentRow In Object.DocumentsForExchange Do
		
		DocumentRow.Use = True;
		
	EndDo;
	
EndProcedure

#EndRegion

#Region Private

&AtServer
Procedure SetEDIProviderVisible()
	
	EDIProviders = Enums.EDIProviders;
	
	If EDIProviders.Count() = 1 Then
		
		Items.Provider.Visible = False;
		
	EndIf;
	
EndProcedure

&AtServer
Procedure FormManagement()
	
	EmptyProvider = (Object.Provider = Enums.EDIProviders.EmptyRef());
	
	
	
EndProcedure

&AtClient
Procedure OnProviderCompanyChange()
	
	FormManagement();
	
	CompanyAttributes = CompanyAttributes(Object.Company);
	
	AttributesNames = New Array;
	AttributesNames.Add("CompanyTaxNumber");
	AttributesNames.Add("CompanyEmail");
	
	
	ListOfAttributes = StringFunctionsClientServer.StringFromSubstringArray(AttributesNames);
	
	FillPropertyValues(Object, CompanyAttributes, ListOfAttributes);
	
EndProcedure

&AtServerNoContext
Function CompanyAttributes(Company)
	
	AttributesNames = New Array;
	AttributesNames.Add("TIN");
	
	
	CompanyAttributes = Common.ObjectAttributesValues(Company, AttributesNames);
	
	Result = New Structure;
	Result.Insert("CompanyTaxNumber", CompanyAttributes.TIN);
	Result.Insert("CompanyEmail", "");
	
	
	Result.CompanyEmail =
		ContactsManager.ObjectContactInformation(Company, Catalogs.ContactInformationKinds.CompanyEmail);
	
	Return Result;
	
EndFunction

&AtClient
Procedure FillDocumentsForExchange()
	
	Object.DocumentsForExchange.Clear();
	DocumentsForExchange = DocumentsForExchange(Object.Provider);
	
	For Each DocumentForExchange In DocumentsForExchange Do
		
		NewRow = Object.DocumentsForExchange.Add();
		NewRow.DocumentType = DocumentForExchange;
		
	EndDo;
	
EndProcedure

&AtServerNoContext
Function DocumentsForExchange(Provider)
	
	Result = New Array;
	
	
	
	Return Result;
	
EndFunction

&AtServerNoContext
Function CompanyInfo(Company)
	
	Result = New Structure;
	
	Result.Insert("CompanyPostalAddress",
		ContactsManager.ObjectContactInformation(Company, Catalogs.ContactInformationKinds.CompanyLegalAddress));
	
	Return Result;

EndFunction

&AtClient
Procedure DoAfterCloseMessageBox(Result) Export
	
	ThisObject.Write();
	
EndProcedure

#EndRegion