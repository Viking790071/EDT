
#Region CommonProceduresAndFunctions

&AtClient
Procedure InsertParameter(Value)
	
	BeginningBookmark = 0;
	EndBookmark = 0;
	Items.FormattedDocument.GetTextSelectionBounds(BeginningBookmark, EndBookmark);
	Try
		BeginningPosition = FormattedDocument.GetBookmarkPosition(BeginningBookmark);
		EndPosition = FormattedDocument.GetBookmarkPosition(EndBookmark);
		
		If BeginningBookmark <> EndBookmark Then 
			FormattedDocument.Delete(BeginningBookmark, EndBookmark);
			Items.FormattedDocument.SetTextSelectionBounds(BeginningBookmark, BeginningBookmark);
		EndIf;
		FormattedDocument.Insert(BeginningBookmark, Value);
		
		EndPosition = BeginningPosition + StrLen(Value);
		EndBookmark = FormattedDocument.GetPositionBookmark(EndPosition);
		Items.FormattedDocument.SetTextSelectionBounds(BeginningBookmark, EndBookmark);
		
		Modified = True;
	Except
	EndTry;
	
EndProcedure

&AtServer
Function EditableParameter()
	
	For ParameterNumber = 0 To Object.EditableParameters.Count() Do
		Presentation = "{FilledField" + (ParameterNumber + 1) + "}";
		If FormattedDocument.FindText(Presentation) <> Undefined Then
			Continue;
		EndIf;
		
		ID = "parameter" + (ParameterNumber + 1);
		If Object.EditableParameters.FindRows(New Structure("ID", ID)).Count() <> 0 Then
			Break;
		Else
			NewRow = Object.EditableParameters.Add();
			NewRow.Presentation = Presentation;
			NewRow.ID = ID;
			Break;
		EndIf;
	EndDo;
	
	Return Presentation;
	
EndFunction

&AtServer
Function InfobaseParameter(Parameter, Case = Undefined)
	
	SimilarParameters = Object.InfobaseParameters.FindRows(New Structure("Parameter", Parameter));
	For ParameterNumber = 0 To SimilarParameters.Count() Do
		
		If TypeOf(Parameter) = Type("EnumRef.ContractsWithCounterpartiesTemplatesParameters") Then
			If ParameterNumber = 0 Then
				Presentation = "{" + Parameter;
			Else
				Presentation = "{" + Parameter + (ParameterNumber + 1);
			EndIf;
		ElsIf TypeOf(Parameter) = Type("ChartOfCharacteristicTypesRef.AdditionalAttributesAndInfo") Then
			If ParameterNumber = 0 Then
				Presentation = "{" + Parameter.Description;
			Else
				Presentation = "{" + Parameter.Description + (ParameterNumber + 1);
			EndIf;
		EndIf;
		
		If FormattedDocument.FindText(Presentation) <> Undefined Then
			Continue;
		EndIf;
		
		If Case <> Undefined Then
			CasePresentation = " (" + Case + ")";
		Else
			CasePresentation = "";
		EndIf;
		
		If TypeOf(Parameter) = Type("EnumRef.ContractsWithCounterpartiesTemplatesParameters") Then
			Presentation = Presentation + CasePresentation + "}";
			ID = "infoParameter" + Parameter + (ParameterNumber + 1);
		ElsIf TypeOf(Parameter) = Type("ChartOfCharacteristicTypesRef.AdditionalAttributesAndInfo") Then
			ParameterNamePresentation = StrReplace(Parameter.Description, " ", "");
			ParameterNamePresentation = StrReplace(ParameterNamePresentation, "(", "");
			ParameterNamePresentation = StrReplace(ParameterNamePresentation, ")", "");
			
			Presentation = Presentation + "}";
			ID = "additionalParameter" + ParameterNamePresentation + (ParameterNumber + 1);
		EndIf;
			
		If Object.InfobaseParameters.FindRows(New Structure("ID", ID)).Count() <> 0 Then
			Break;
		Else
			NewRow = Object.InfobaseParameters.Add();
			NewRow.Presentation = Presentation;
			NewRow.ID = ID;
			NewRow.Parameter = Parameter;
			Break;
		EndIf;
	EndDo;
	
	Return Presentation;
	
EndFunction

&AtClient
Procedure InsertInfobaseParameter(InfobaseParameter, Case = Undefined)
	
	InsertParameter("%Parameter%");
	
	If FormattedDocument.FindText("%Parameter%") <> Undefined Then 
		
		Parameter = InfobaseParameter(InfobaseParameter, Case);
		
		BeginningBookmark = FormattedDocument.FindText("%Parameter%").BeginBookmark;
		EndBookmark = FormattedDocument.FindText("%Parameter%").EndBookmark;
		
		BeginningPosition = FormattedDocument.GetBookmarkPosition(BeginningBookmark);
		EndPosition = BeginningPosition + StrLen(Parameter);
		
		FormattedDocument.Delete(BeginningBookmark, EndBookmark);
		FormattedDocument.Insert(BeginningBookmark, Parameter);
		
		EndBookmark = FormattedDocument.GetPositionBookmark(EndPosition);
		Items.FormattedDocument.SetTextSelectionBounds(BeginningBookmark, EndBookmark);
	EndIf;
	
EndProcedure

&AtServer
Procedure RestorePredefinedFormByDefaultAtServer()
	ContractTemplate = Catalogs.ContractForms.GetTemplate(Object.PredefinedFormTemplate);
	TextHTML = ContractTemplate.GetText();
	Attachments = New Structure;
	
	EditableParameters = Object.EditableParameters.Unload();
	
	If EditableParameters.Count() <> Object.EditableParametersNumber Then 
		
		VT = New ValueTable;
		VT.Columns.Add("Presentation");
		VT.Columns.Add("ID");
		
		For Each String In EditableParameters Do 
			If String.LineNumber <= Object.EditableParametersNumber Then 
				NewRow = VT.Add();
				NewRow.Presentation = String.Presentation;
				NewRow.ID = String.ID;
			EndIf;
		EndDo;
		
		Object.EditableParameters.Load(VT);
	EndIf;
	
	Object.InfobaseParameters.Clear();
	
	Cases = New Array;
	Cases.Add(Undefined);
	Cases.Add("nominative");
	Cases.Add("genitive");
	Cases.Add("dative");
	Cases.Add("accusative");
	Cases.Add("instrumental");
	Cases.Add("prepositional");
	
	For Each ParameterEnumeration In Enums.ContractsWithCounterpartiesTemplatesParameters Do
		
		For Each Case In Cases Do
			If Case = Undefined Then
				PresentationCase = "";
			Else
				PresentationCase = " (" + Case + ")";
			EndIf;
			
			Parameter = "{" + String(ParameterEnumeration) + PresentationCase + "}";
			OccurrenceCount = StrOccurrenceCount(TextHTML, Parameter);
			For ParameterNumber = 1 To OccurrenceCount Do
				If ParameterNumber = 1 Then
					Presentation = "{" + String(ParameterEnumeration) + PresentationCase + "%deleteSymbols%" + "}";
					ID = "infoParameter" + String(ParameterEnumeration) + ParameterNumber;
				Else
					Presentation = "{" + String(ParameterEnumeration) + ParameterNumber + PresentationCase + "}";
					ID = "infoParameter" + String(ParameterEnumeration) + ParameterNumber;
				EndIf;
				
				FirstOccurence = Find(TextHTML, Parameter);
				
				TextHTML = Left(TextHTML, FirstOccurence - 1) + Presentation + Mid(TextHTML, FirstOccurence + StrLen(Parameter));
				
				NewRow = Object.InfobaseParameters.Add();
				NewRow.Presentation = StrReplace(Presentation, "%deleteSymbols%", "");
				NewRow.ID = ID;
				NewRow.Parameter = ParameterEnumeration;
				
			EndDo;
			TextHTML = StrReplace(TextHTML, "%deleteSymbols%", "");
		EndDo;
	EndDo;
	
	FormattedDocument.SetHTML(TextHTML, Attachments);
	
	Modified = True;
EndProcedure

&AtServer
Procedure AddAdditionalAttributesInsert(FormGroup, AttributesToAdd)
	
	Iterator = 0;
	For Each Attribute In AttributesToAdd Do 
		
		CommandName = "InsertAdditionalAttribute" + FormGroup.Name + Iterator;
		DescriptionAttribute = Attribute.Title;
		
		Command = Commands.Add(CommandName);
		Command.Title = DescriptionAttribute;
		Command.Action = "InsertAdditionalAttribute";
		
		Button = Items.Add(CommandName, Type("FormButton"), FormGroup);
		Button.CommandName = CommandName;
		Button.Title = DescriptionAttribute;
		
		NewRow = AdditionalAttributesVT.Add();
		NewRow.CommandName = CommandName;
		NewRow.Attribute = Attribute;
		
		Iterator = Iterator + 1;
		
	EndDo;
	
EndProcedure

#EndRegion

#Region FormEventsHandlers

&AtServer
Procedure BeforeWriteAtServer(Cancel, CurrentObject, WriteParameters)
	
	HTMLText = "";
	Attachments = New Structure;
	FormattedDocument.GetHTML(HTMLText, Attachments);
	
	FormattedDocumentStructure = New Structure;
	FormattedDocumentStructure.Insert("HTMLText", HTMLText);
	FormattedDocumentStructure.Insert("Attachments", Attachments);
	CurrentObject.Form = New ValueStorage(FormattedDocumentStructure);
	
	Iterator = 0;
	While Iterator < CurrentObject.EditableParameters.Count() Do 
		
		If Find(HTMLText, CurrentObject.EditableParameters[Iterator].Presentation) <> 0 Then 
			Iterator = Iterator + 1;
			Continue;
		EndIf;
		
		CurrentObject.EditableParameters.Delete(CurrentObject.EditableParameters[Iterator]);
		
	EndDo;
	
	Iterator = 0;
	While Iterator < CurrentObject.InfobaseParameters.Count() Do 
		
		If Find(HTMLText, CurrentObject.InfobaseParameters[Iterator].Presentation) <> 0 Then 
			Iterator = Iterator + 1;
			Continue;
		EndIf;
		
		CurrentObject.InfobaseParameters.Delete(CurrentObject.InfobaseParameters[Iterator]);
		
	EndDo;

	NativeLanguagesSupportServer.BeforeWriteAtServer(CurrentObject);
	
EndProcedure

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	CopyingValue = Undefined;
	Parameters.Property("CopyingValue", CopyingValue);
	
	If ValueIsFilled(Object.PredefinedFormTemplate) Then 
		Items.RecallPredefinedFormDefault.Visible = True;
	Else 
		Items.RecallPredefinedFormDefault.Visible = False;
	EndIf;
	
	If ValueIsFilled(Object.Ref) Then
		If Object.Ref.Form.Get() <> Undefined Then 
			FormattedDocument.SetHTML(Object.Ref.Form.Get().HTMLText,
													Object.Ref.Form.Get().Attachments);
		EndIf;
	ElsIf ValueIsFilled(CopyingValue.Ref) Then 
		If CopyingValue.Ref.Form.Get() <> Undefined Then 
			FormattedDocument.SetHTML(CopyingValue.Ref.Form.Get().HTMLText,
													CopyingValue.Ref.Form.Get().Attachments);
		EndIf;
	Else 
		FormattedDocument = New FormattedDocument;
	EndIf;
	
	SalesOrderAdditionalAttributes = PropertyManager.GetPropertyList(Documents.SalesOrder.EmptyRef(), True, False);
	InvoiceAdditionalAttributes = PropertyManager.GetPropertyList(Documents.Quote.EmptyRef(), True, False);
	CounterpartyContractsAdditionalAttributes = PropertyManager.GetPropertyList(Catalogs.CounterpartyContracts.EmptyRef(), True, False);
	AdditionalAttributesCounterparty = PropertyManager.GetPropertyList(Catalogs.Counterparties.EmptyRef(), True, False);
	
	AddAdditionalAttributesInsert(Items.GroupAdditionalAttributesSalesOrder, SalesOrderAdditionalAttributes);
	AddAdditionalAttributesInsert(Items.GroupInvoiceAdditionalAttributes, InvoiceAdditionalAttributes);
	AddAdditionalAttributesInsert(Items.ContractSettingsGroup, CounterpartyContractsAdditionalAttributes);
	AddAdditionalAttributesInsert(Items.CounterpartySettingsGroup, AdditionalAttributesCounterparty);
	
	FormattedDocument.GetHTML(FormTextAtOpening, New Structure());
	
	NativeLanguagesSupportServer.OnCreateAtServer(ThisObject, Object);
	
EndProcedure

&AtServer
Procedure AfterWriteAtServer(CurrentObject, WriteParameters)

	NativeLanguagesSupportServer.OnReadPresentationsAtServer(Object);
	
EndProcedure

&AtServer
Procedure OnReadAtServer(CurrentObject)

	NativeLanguagesSupportServer.OnReadPresentationsAtServer(Object);
	
EndProcedure

&AtClient
Procedure OnClose(Exit)
	FormText = "";
	FormattedDocument.GetHTML(FormText, New Structure());
	If FormText <> FormTextAtOpening Then
		Notify("ContractTemplateChangeAndRecordAtServer", Object.Ref);
	EndIf;
EndProcedure

#EndRegion

#Region FormItemEventsHandlers

&AtClient
Procedure FormattedDocumentOnChange(Item)
	Modified = True;
EndProcedure

&AtClient
Procedure Attachable_Open(Item, StandardProcessing)
	NativeLanguagesSupportClient.OnOpen(ThisObject, Object, Item, StandardProcessing);
EndProcedure

#EndRegion

#Region FormCommandPanelsEventsHandlers

&AtClient
Procedure InsertCounterpartyEMailAddress(Command)
	InsertInfobaseParameter(PredefinedValue("Enum.ContractsWithCounterpartiesTemplatesParameters.CounterpartyEMailAddress"));
EndProcedure

&AtClient
Procedure InsertCompanyEmailAddress(Command)
	InsertInfobaseParameter(PredefinedValue("Enum.ContractsWithCounterpartiesTemplatesParameters.CompanyEmailAddress"));
EndProcedure

&AtClient
Procedure InsertCounterpartyBank(Command)
	InsertInfobaseParameter(PredefinedValue("Enum.ContractsWithCounterpartiesTemplatesParameters.CounterpartyBank"));
EndProcedure

&AtClient
Procedure InsertCompanyBank(Command)
	InsertInfobaseParameter(PredefinedValue("Enum.ContractsWithCounterpartiesTemplatesParameters.BankCompany"));
EndProcedure

&AtClient
Procedure InsertContractDate(Command)
	InsertInfobaseParameter(PredefinedValue("Enum.ContractsWithCounterpartiesTemplatesParameters.Date"));
EndProcedure

&AtClient
Procedure InsertCounterpartyContactPersonPositionSubjective(Command)
	InsertInfobaseParameter(PredefinedValue("Enum.ContractsWithCounterpartiesTemplatesParameters.PositionOfContactPersonOfCounterparty"), "nominative");
EndProcedure

&AtClient
Procedure InsertCounterpartyContactPersonPositionGenitive(Command)
	InsertInfobaseParameter(PredefinedValue("Enum.ContractsWithCounterpartiesTemplatesParameters.PositionOfContactPersonOfCounterparty"), "genitive");
EndProcedure

&AtClient
Procedure InsertCounterpartyContactPersonPositionDative(Command)
	InsertInfobaseParameter(PredefinedValue("Enum.ContractsWithCounterpartiesTemplatesParameters.PositionOfContactPersonOfCounterparty"), "dative");
EndProcedure

&AtClient
Procedure InsertCounterpartyContactPersonPositionAccusative(Command)
	InsertInfobaseParameter(PredefinedValue("Enum.ContractsWithCounterpartiesTemplatesParameters.PositionOfContactPersonOfCounterparty"), "accusative");
EndProcedure

&AtClient
Procedure InsertCounterpartyContactPersonPositionAblative(Command)
	InsertInfobaseParameter(PredefinedValue("Enum.ContractsWithCounterpartiesTemplatesParameters.PositionOfContactPersonOfCounterparty"), "instrumental");
EndProcedure

&AtClient
Procedure InsertCounterpartyContactPersonPositionLocative(Command)
	InsertInfobaseParameter(PredefinedValue("Enum.ContractsWithCounterpartiesTemplatesParameters.PositionOfContactPersonOfCounterparty"), "prepositional");
EndProcedure

&AtClient
Procedure InsertCounterpartyTIN(Command)
	InsertInfobaseParameter(PredefinedValue("Enum.ContractsWithCounterpartiesTemplatesParameters.CounterpartyTIN"));
EndProcedure

&AtClient
Procedure InsertCompanyTIN(Command)
	InsertInfobaseParameter(PredefinedValue("Enum.ContractsWithCounterpartiesTemplatesParameters.CompanyTIN"));
EndProcedure

&AtClient
Procedure InsertCounterpartyContactPersonSubjenctive(Command)
	InsertInfobaseParameter(PredefinedValue("Enum.ContractsWithCounterpartiesTemplatesParameters.ContactPersonOfCounterparty"), "nominative");
EndProcedure

&AtClient
Procedure InsertCounterpartyContactPersonGenitive(Command)
	InsertInfobaseParameter(PredefinedValue("Enum.ContractsWithCounterpartiesTemplatesParameters.ContactPersonOfCounterparty"), "genitive");
EndProcedure

&AtClient
Procedure InsertContactPersonOfCounterpartyDating(Command)
	InsertInfobaseParameter(PredefinedValue("Enum.ContractsWithCounterpartiesTemplatesParameters.ContactPersonOfCounterparty"), "dative");
EndProcedure

&AtClient
Procedure InsertCounterpartyContactPersonAccusative(Command)
	InsertInfobaseParameter(PredefinedValue("Enum.ContractsWithCounterpartiesTemplatesParameters.ContactPersonOfCounterparty"), "accusative");
EndProcedure

&AtClient
Procedure InsertCounterpartyContactPersonAblative(Command)
	InsertInfobaseParameter(PredefinedValue("Enum.ContractsWithCounterpartiesTemplatesParameters.ContactPersonOfCounterparty"), "instrumental");
EndProcedure

&AtClient
Procedure InsertCounterpartyContactPersonLocative(Command)
	InsertInfobaseParameter(PredefinedValue("Enum.ContractsWithCounterpartiesTemplatesParameters.ContactPersonOfCounterparty"), "prepositional");
EndProcedure

&AtClient
Procedure InsertCompanyName(Command)
	InsertInfobaseParameter(PredefinedValue("Enum.ContractsWithCounterpartiesTemplatesParameters.CompanyName"));
EndProcedure

&AtClient
Procedure InsertCounterpartyName(Command)
	InsertInfobaseParameter(PredefinedValue("Enum.ContractsWithCounterpartiesTemplatesParameters.CompanyName"));
EndProcedure

&AtClient
Procedure InsertContractNo(Command)
	InsertInfobaseParameter(PredefinedValue("Enum.ContractsWithCounterpartiesTemplatesParameters.ContractNo"));
EndProcedure

&AtClient
Procedure InsertCompanyOKTMO(Command)
	InsertInfobaseParameter(PredefinedValue("Enum.ContractsWithCounterpartiesTemplatesParameters.CompanyOKTMO"));
EndProcedure

&AtClient
Procedure InsertCompanyOKATO(Command)
	InsertInfobaseParameter(PredefinedValue("Enum.ContractsWithCounterpartiesTemplatesParameters.CompanyOKATO"));
EndProcedure

&AtClient
Procedure InsertCounterpartyOKPO(Command)
	InsertInfobaseParameter(PredefinedValue("Enum.ContractsWithCounterpartiesTemplatesParameters.CounterpartyRNCBO"));
EndProcedure

&AtClient
Procedure InsertCompanyOKPO(Command)
	InsertInfobaseParameter(PredefinedValue("Enum.ContractsWithCounterpartiesTemplatesParameters.CompanyRNCBO"));
EndProcedure

&AtClient
Procedure InsertCounterpartyPostalAddress(Command)
	InsertInfobaseParameter(PredefinedValue("Enum.ContractsWithCounterpartiesTemplatesParameters.CounterpartyPostalAddress"));
EndProcedure

&AtClient
Procedure InsertCompanyPostalAddress(Command)
	InsertInfobaseParameter(PredefinedValue("Enum.ContractsWithCounterpartiesTemplatesParameters.CounterpartyPostalAddress"));
EndProcedure

&AtClient
Procedure InsertCounterpartyBankAcc(Command)
	InsertInfobaseParameter(PredefinedValue("Enum.ContractsWithCounterpartiesTemplatesParameters.CounterpartyBankAcc"));
EndProcedure

&AtClient
Procedure InsertCompanyBankAcc(Command)
	InsertInfobaseParameter(PredefinedValue("Enum.ContractsWithCounterpartiesTemplatesParameters.CompanyBankAcc"));
EndProcedure

&AtClient
Procedure InsertCounterpartyPhone(Command)
	InsertInfobaseParameter(PredefinedValue("Enum.ContractsWithCounterpartiesTemplatesParameters.CounterpartyPhone"));
EndProcedure

&AtClient
Procedure InsertCompanyPhone(Command)
	InsertInfobaseParameter(PredefinedValue("Enum.ContractsWithCounterpartiesTemplatesParameters.CompanyPhone"));
EndProcedure

&AtClient
Procedure InsertCounterpartyFax(Command)
	InsertInfobaseParameter(PredefinedValue("Enum.ContractsWithCounterpartiesTemplatesParameters.CounterpartyFax"));
EndProcedure

&AtClient
Procedure InsertCompanyFax(Command)
	InsertInfobaseParameter(PredefinedValue("Enum.ContractsWithCounterpartiesTemplatesParameters.CounterpartyFax"));
EndProcedure

&AtClient
Procedure InsertCounterpartyFactAddress(Command)
	InsertInfobaseParameter(PredefinedValue("Enum.ContractsWithCounterpartiesTemplatesParameters.CounterpartyFactAddress"));
EndProcedure

&AtClient
Procedure InsertCompanyActualAddress(Command)
	InsertInfobaseParameter(PredefinedValue("Enum.ContractsWithCounterpartiesTemplatesParameters.CompanyActualAddress"));
EndProcedure

&AtClient
Procedure InsertCounterpartyLegalAddress(Command)
	InsertInfobaseParameter(PredefinedValue("Enum.ContractsWithCounterpartiesTemplatesParameters.CounterpartyLegalAddress"));
EndProcedure

&AtClient
Procedure InsertCompanyLegalAddress(Command)
	InsertInfobaseParameter(PredefinedValue("Enum.ContractsWithCounterpartiesTemplatesParameters.CompanyLegalAddress"));
EndProcedure

&AtClient
Procedure InsertDocumentAmount(Command)
	InsertInfobaseParameter(PredefinedValue("Enum.ContractsWithCounterpartiesTemplatesParameters.DocumentAmount"));
EndProcedure

&AtClient
Procedure InsertHeadCompaniesNominative(Command)
	InsertInfobaseParameter(PredefinedValue("Enum.ContractsWithCounterpartiesTemplatesParameters.CompanyHead"), "nominative");
EndProcedure

&AtClient
Procedure InsertCompanyTopManagerGenitive(Command)
	InsertInfobaseParameter(PredefinedValue("Enum.ContractsWithCounterpartiesTemplatesParameters.CompanyHead"), "genitive");
EndProcedure

&AtClient
Procedure InsertCompanyTopManagerDative(Command)
	InsertInfobaseParameter(PredefinedValue("Enum.ContractsWithCounterpartiesTemplatesParameters.CompanyHead"), "dative");
EndProcedure

&AtClient
Procedure InsertCompanyTopManagerAccusative(Command)
	InsertInfobaseParameter(PredefinedValue("Enum.ContractsWithCounterpartiesTemplatesParameters.CompanyHead"), "accusative");
EndProcedure

&AtClient
Procedure InsertCompanyTopManagerAblative(Command)
	InsertInfobaseParameter(PredefinedValue("Enum.ContractsWithCounterpartiesTemplatesParameters.CompanyHead"), "instrumental");
EndProcedure

&AtClient
Procedure InsertCompanyTopManagerLocative(Command)
	InsertInfobaseParameter(PredefinedValue("Enum.ContractsWithCounterpartiesTemplatesParameters.CompanyHead"), "prepositional");
EndProcedure

&AtClient
Procedure InsertEditableParameter(Command)
	
	InsertParameter("%Parameter%");
	
	If FormattedDocument.FindText("%Parameter%") <> Undefined Then 
		
		EditableParameter = EditableParameter();
		
		BeginningBookmark = FormattedDocument.FindText("%Parameter%").BeginBookmark;
		EndBookmark = FormattedDocument.FindText("%Parameter%").EndBookmark;
		
		BeginningPosition = FormattedDocument.GetBookmarkPosition(BeginningBookmark);
		EndPosition = BeginningPosition + StrLen("{FilledField}") + 1;
		
		FormattedDocument.Delete(BeginningBookmark, EndBookmark);
		FormattedDocument.Insert(BeginningBookmark, EditableParameter);
		
		EndBookmark = FormattedDocument.GetPositionBookmark(EndPosition);
		Items.FormattedDocument.SetTextSelectionBounds(BeginningBookmark, EndBookmark);
	EndIf;
	
EndProcedure

&AtClient
Procedure RecallPredefinedFormDefault(Command)
	RestorePredefinedFormByDefaultAtServer();
	Notify("PredefinedTemplateRestoration", Object.Ref);
EndProcedure

&AtClient
Procedure InsertCompanyBIK(Command)
	InsertInfobaseParameter(PredefinedValue("Enum.ContractsWithCounterpartiesTemplatesParameters.CompanyBIK"));
EndProcedure

&AtClient
Procedure InsertCounterpartyBIK(Command)
	InsertInfobaseParameter(PredefinedValue("Enum.ContractsWithCounterpartiesTemplatesParameters.CounterpartyBIK"));
EndProcedure

&AtClient
Procedure InsertCounterpartyCorrespondentAccount(Command)
	InsertInfobaseParameter(PredefinedValue("Enum.ContractsWithCounterpartiesTemplatesParameters.CorrCounterpartyAccount"));
EndProcedure

&AtClient
Procedure InsertPassportDataIssueDate(Command)
	InsertInfobaseParameter(PredefinedValue("Enum.ContractsWithCounterpartiesTemplatesParameters.PassportData_IssueDate"));
EndProcedure

&AtClient
Procedure InsertPassportDataIssuingAuthority(Command)
	InsertInfobaseParameter(PredefinedValue("Enum.ContractsWithCounterpartiesTemplatesParameters.PassportData_Authority"));
EndProcedure

&AtClient
Procedure InsertPassportDataNumber(Command)
	InsertInfobaseParameter(PredefinedValue("Enum.ContractsWithCounterpartiesTemplatesParameters.PassportData_Number"));
EndProcedure

&AtClient
Procedure InsertPassportDataValidityPeriod(Command)
	InsertInfobaseParameter(PredefinedValue("Enum.ContractsWithCounterpartiesTemplatesParameters.PassportData_ExpiryDate"));
EndProcedure

&AtClient
Procedure InsertFacsimile(Command)
	InsertInfobaseParameter(PredefinedValue("Enum.ContractsWithCounterpartiesTemplatesParameters.Facsimile"));
EndProcedure

&AtClient
Procedure InsertPageBreak(Command)
	InsertParameter("/*PageBreak*/");
EndProcedure

&AtClient
Procedure InsertLogo(Command)
	InsertInfobaseParameter(PredefinedValue("Enum.ContractsWithCounterpartiesTemplatesParameters.Logo"));
EndProcedure

&AtClient
Procedure InsertDocumentDate(Command)
	InsertInfobaseParameter(PredefinedValue("Enum.ContractsWithCounterpartiesTemplatesParameters.DocumentDate"));
EndProcedure

&AtClient
Procedure InsertDocumentNumber(Command)
	InsertInfobaseParameter(PredefinedValue("Enum.ContractsWithCounterpartiesTemplatesParameters.DocumentNumber"));
EndProcedure

&AtClient
Procedure InsertAdditionalAttribute(Command)
	Rows = AdditionalAttributesVT.FindRows(New Structure("CommandName", Command.Name));
	If Rows.Count() <> 0 Then
		InsertInfobaseParameter(Rows[0].Attribute);
	EndIf;
EndProcedure

&AtClient
Procedure InsertCompanyTopManagerDescriptionFullSubjective(Command)
	InsertInfobaseParameter(PredefinedValue("Enum.ContractsWithCounterpartiesTemplatesParameters.CompanyHeadInitials"), "nominative");
EndProcedure

&AtClient
Procedure InsertCompanyTopManagerDescriptionFullGenitive(Command)
	InsertInfobaseParameter(PredefinedValue("Enum.ContractsWithCounterpartiesTemplatesParameters.CompanyHeadInitials"), "genitive");
EndProcedure

&AtClient
Procedure InsertCompanyTopManagerNameDative(Command)
	InsertInfobaseParameter(PredefinedValue("Enum.ContractsWithCounterpartiesTemplatesParameters.CompanyHeadInitials"), "dative");
EndProcedure

&AtClient
Procedure InsertCompanyTopManagerDescriptionFullAccusative(Command)
	InsertInfobaseParameter(PredefinedValue("Enum.ContractsWithCounterpartiesTemplatesParameters.CompanyHeadInitials"), "accusative");
EndProcedure

&AtClient
Procedure InsertCompanyTopManagerDescriptionFullAblative(Command)
	InsertInfobaseParameter(PredefinedValue("Enum.ContractsWithCounterpartiesTemplatesParameters.CompanyHeadInitials"), "instrumental");
EndProcedure

&AtClient
Procedure InsertCompanyTopManagerDescriptionFullLocative(Command)
	InsertInfobaseParameter(PredefinedValue("Enum.ContractsWithCounterpartiesTemplatesParameters.CompanyHeadInitials"), "prepositional");
EndProcedure

&AtClient
Procedure InsertCounterpartyContactPersonPositionDescriptionFullSubjective(Command)
	InsertInfobaseParameter(PredefinedValue("Enum.ContractsWithCounterpartiesTemplatesParameters.ContactPersonOfCounterpartyInitials"), "nominative");
EndProcedure

&AtClient
Procedure InsertCounterpartyContactPersonPositionDescriptionFullGenitive(Command)
	InsertInfobaseParameter(PredefinedValue("Enum.ContractsWithCounterpartiesTemplatesParameters.ContactPersonOfCounterpartyInitials"), "genitive");
EndProcedure

&AtClient
Procedure InsertCounterpartyContactPersonPositionDescriptionFullDative(Command)
	InsertInfobaseParameter(PredefinedValue("Enum.ContractsWithCounterpartiesTemplatesParameters.ContactPersonOfCounterpartyInitials"), "dative");
EndProcedure

&AtClient
Procedure InsertCounterpartyContactPersonPositionDescriptionFullAccusative(Command)
	InsertInfobaseParameter(PredefinedValue("Enum.ContractsWithCounterpartiesTemplatesParameters.ContactPersonOfCounterpartyInitials"), "accusative");
EndProcedure

&AtClient
Procedure InsertCounterpartyContactPersonPositionDescriptionFullAblative(Command)
	InsertInfobaseParameter(PredefinedValue("Enum.ContractsWithCounterpartiesTemplatesParameters.ContactPersonOfCounterpartyInitials"), "instrumental");
EndProcedure

&AtClient
Procedure InsertCounterpartyContactPersonPositionDescriptionFullLocative(Command)
	InsertInfobaseParameter(PredefinedValue("Enum.ContractsWithCounterpartiesTemplatesParameters.ContactPersonOfCounterpartyInitials"), "prepositional");
EndProcedure

#EndRegion