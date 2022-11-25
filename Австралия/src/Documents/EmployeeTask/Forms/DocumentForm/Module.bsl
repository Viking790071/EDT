
#Region Internal

&AtServerNoContext
// Gets data set from server.
//
Function GetCompanyDataOnChange(Company)
	
	StructureData = New Structure();
	StructureData.Insert("Company", DriveServer.GetCompany(Company));
	
	Return StructureData;
	
EndFunction

&AtClient
// Procedure calculates the operation duration.
//
// Parameters:
//  No.
//
Procedure CalculateDuration(CurrentRow)
	
	DurationInSeconds = CurrentRow.EndTime - CurrentRow.BeginTime;
	
	Hours = Int(DurationInSeconds / 3600);
	Minutes = (DurationInSeconds - Hours * 3600) / 60;
	
	CurrentRow.Duration = Date(0001, 01, 01, Hours, Minutes, 0);
	
	CalculateDurationInHours(CurrentRow);

EndProcedure

&AtClient
// Procedure calculates the operation duration.
//
// Parameters:
//  No.
//
Procedure CalculateDurationInHours(CurrentRow)
	
	CurrentRow.DurationInHours = Round(Hour(CurrentRow.Duration) + Minute(CurrentRow.Duration) / 60, 2);
	
EndProcedure

&AtServer
// Procedure calculates the operation duration.
//
// Parameters:
//  No.
//
Procedure CalculateDurationAtServer(CurrentRow)
	
	DurationInSeconds = CurrentRow.EndTime - CurrentRow.BeginTime;
	
	Hours = Int(DurationInSeconds / 3600);
	Minutes = (DurationInSeconds - Hours * 3600) / 60;
	
	CurrentRow.Duration = Date(0001, 01, 01, Hours, Minutes, 0);
	CurrentRow.DurationInHours = Round(Hour(CurrentRow.Duration) + Minute(CurrentRow.Duration) / 60, 2);
	
EndProcedure

&AtClient
// Procedure calculates amount.
//
// Parameters:
//  No.
//
Procedure CalculateAmount(CurrentRow)
	
	CurrentRow.Amount = CurrentRow.DurationInHours * CurrentRow.Price;
	
EndProcedure

&AtServer
// Procedure sets availability of the form items.
//
// Parameters:
//  No.
//
Procedure SetVisibleAndEnabledFromOperationKind()
	
	If OperationKind = Enums.OperationTypesEmployeeTask.External Then
		
		Items.PriceKind.Visible = True;
		Items.GroupCost.Visible = True;
		Items.WorksConsumer.Visible = True;
		Items.WorksProducts.Visible = True;
		Items.WorksCharacteristic.Visible = True;
		
		Items.WorksRowConsumer.Visible = True;
		Items.WorksRowProducts.Visible = True;
		Items.WorksRowCharacteristic.Visible = True;
		
		Items.WorksPrice.Visible = True;
		Items.WorksAmount.Visible = True;
		
		Items.TotalsAmount.Visible = True;
		
	ElsIf OperationKind = Enums.OperationTypesEmployeeTask.Inner Then
		
		Items.PriceKind.Visible = False;
		Items.GroupCost.Visible = False;
		Items.WorksConsumer.Visible = False;
		Items.WorksProducts.Visible = False;
		Items.WorksCharacteristic.Visible = False;
		
		Items.WorksRowConsumer.Visible = False;
		Items.WorksRowProducts.Visible = False;
		Items.WorksRowCharacteristic.Visible = False;
		
		Items.WorksPrice.Visible = False;
		Items.WorksAmount.Visible = False;
		
		Items.TotalsAmount.Visible = False;
		
		For Each TSRow In Object.Works Do
			TSRow.Price = 0;
			TSRow.Amount = 0;
		EndDo;
		
	EndIf; 
	
	ThisIsFullRights = IsInRole(Metadata.Roles.FullRights);
	
	Items.PriceKind.Visible = ThisIsFullRights OR IsInRole(Metadata.Roles.AddEditMarketingSubsystem);
	Items.GroupCost.Visible = ThisIsFullRights OR IsInRole(Metadata.Roles.AddEditSalesSubsystem);
	Items.ConsumerWorkService.Visible = ThisIsFullRights OR IsInRole(Metadata.Roles.AddEditSalesSubsystem);
	
EndProcedure

// Procedure sets the form item visible.
//
// Parameters:
//  No.
//
&AtServer
Procedure SetVisibleFromUserSettings()	
	
	If Object.WorkKindPosition = Enums.AttributeStationing.InHeader Then
		Items.WorksWorksKind.Visible = False;
		Items.WorksRowWorkKind.Visible = False;
		WorkKindInHeader = True;
		
		Items.WorkKind.Visible = True;
		Items.WorksRowWorkKind.Visible = False;
		Items.WorkKindAsList.Visible = True;
		
	Else
		Items.WorksWorksKind.Visible = True;
		Items.WorksRowWorkKind.Visible = True;
		WorkKindInHeader = False;
		
		Items.WorkKind.Visible = False;
		Items.WorksRowWorkKind.Visible = True;
		Items.WorkKindAsList.Visible = False;
		
	EndIf;	
	
EndProcedure

&AtServer
Procedure SetPriceTypesChoiceList()

	WorkWithForm.SetChoiceParametersByCompany(Object.Company, ThisForm, "PriceKind");
	
EndProcedure

// Procedure - Set edit by list option.
//
&AtClient
Procedure SetEditInListOption()
	
	Items.EditInList.Check = Not Items.EditInList.Check;
	
	LineCount = Object.Works.Count();
	
	If Not Items.EditInList.Check
		  AND Object.Works.Count() > 1 Then
		
		Response = Undefined;

		
		ShowQueryBox(New NotifyDescription("SetEditInListEndOption", ThisObject, New Structure("LineCount", LineCount)), 
			NStr("en = 'All lines except for the first one will be deleted. Continue?'; ru = 'Все строки кроме первой будут удалены. Продолжить?';pl = 'Wszystkie wiersze za wyjątkiem pierwszego zostaną usunięte. Kontynuować?';es_ES = 'Todas las líneas a excepción de la primera se eliminarán. ¿Continuar?';es_CO = 'Todas las líneas a excepción de la primera se eliminarán. ¿Continuar?';tr = 'İlki haricinde tüm satırlar silinecek. Devam edilsin mi?';it = 'Tutte le linee eccetto la prima saranno cancellate. Continuare?';de = 'Alle Zeilen bis auf die erste werden gelöscht. Fortsetzen?'"),
			QuestionDialogMode.YesNo);
		Return;
	EndIf;
	
	SetEditInListFragmentOption();
EndProcedure

&AtClient
Procedure SetEditInListEndOption(Result, AdditionalParameters) Export
    
    LineCount = AdditionalParameters.LineCount;
    
    
    Response = Result;
    
    If Response = DialogReturnCode.No Then
        Items.EditInList.Check = True;
        Return;
    EndIf;
    
    While LineCount > 1 Do
        Object.Works.Delete(Object.Works[LineCount - 1]);
        LineCount = LineCount - 1;
    EndDo;
    Items.Works.CurrentRow = Object.Works[0].GetID();
    
    SetEditInListFragmentOption();

EndProcedure

&AtClient
Procedure SetEditInListFragmentOption()
    
    If Items.EditInList.Check Then
        Items.Pages.CurrentPage = Items.List;
    Else
        Items.Pages.CurrentPage = Items.OneRow;
    EndIf;

EndProcedure

&AtServerNoContext
// Recalculate the price of the tabular section of the document after making changes in the "Prices and currency" form.
//
// Parameters:
//  AttributesStructure - Attribute structure, which necessary when recalculation
//  DocumentTabularSection - FormDataStructure, it
//                 contains the tabular document part.
//
Procedure GetTabularSectionPricesByPriceKind(DataStructure, DocumentTabularSection)
	
	// 1. Filter by products	
	ProductsArray = New Array;	
	For Each TSRow In DocumentTabularSection Do		
		ProductsArray.Add(TSRow.Products);
	EndDo;
	
	// 2. We will fill prices.
	If DataStructure.PriceKind.CalculatesDynamically Then
		DynamicPriceKind = True;
		PriceKindParameter = DataStructure.PriceKind.PricesBaseKind;
		Markup = DataStructure.PriceKind.Percent;
	Else
		DynamicPriceKind = False;
		PriceKindParameter = DataStructure.PriceKind;	
	EndIf;	
	
	Query = New Query;
	
	Query.Text = 
	"SELECT ALLOWED
	|	PricesSliceLast.Products AS Products,
	|	PricesSliceLast.PriceKind.PriceCurrency AS PricesCurrency,
	|	PricesSliceLast.PriceKind.PriceIncludesVAT AS PriceIncludesVAT,
	|	ISNULL(PricesSliceLast.Price, 0) AS Price
	|FROM
	|	InformationRegister.Prices.SliceLast(
	|			&ProcessingDate,
	|			PriceKind = &PriceKind
	|				AND Products IN (&ProductsArray)) AS PricesSliceLast";
		
	Query.SetParameter("ProcessingDate",	 DataStructure.Date);
	Query.SetParameter("PriceKind",			 PriceKindParameter);
	Query.SetParameter("ProductsArray", ProductsArray);
	
	PricesTable = Query.Execute().Unload();
	For Each TabularSectionRow In DocumentTabularSection Do
		
		SearchStructure = New Structure;
		SearchStructure.Insert("Products",	 TabularSectionRow.Products);
		
		SearchResult = PricesTable.FindRows(SearchStructure);
		If SearchResult.Count() > 0 Then
			
			Price = SearchResult[0].Price;
			If Price = 0 Then
				TabularSectionRow.Price = Price;
			Else
				
				// Dynamically calculate the price
				If DynamicPriceKind Then
					
					Price = Price * (1 + Markup / 100);
					
				EndIf; 
				
				TabularSectionRow.Price = DriveClientServer.RoundPrice(Price, Enums.RoundingMethods.Round0_01); 
				
			EndIf;
			
		Else
			
			TabularSectionRow.Price = 0;
		
		EndIf;
		
	EndDo;
	
EndProcedure

&AtServerNoContext
// Gets work price.
//
Function GetPrice(StructureData)
	
	StructureData.Insert("Characteristic", Catalogs.ProductsCharacteristics.EmptyRef());
	StructureData.Insert("AmountIncludesVAT", StructureData.PriceKind.PriceIncludesVAT);
	StructureData.Insert("DocumentCurrency", StructureData.PriceKind.PriceCurrency);
	StructureData.Insert("Factor", 1);
	
	StructureData.Insert("Price", DriveServer.GetProductsPriceByPriceKind(StructureData));
	
	Return StructureData;
	
EndFunction

&AtClient
Function PricesFields()
	
	Fields = New Array();
	Fields.Add(Items.WorksPrice);
	Fields.Add(Items.WorkStringPrice);
	
	Return Fields;
	
EndFunction

#EndRegion

#Region FormCommandsHandlers

// Procedure - EditByList command handler.
//
&AtClient
Procedure EditInList(Command)
	
	SetEditInListOption();
	
EndProcedure

// Procedure - command handler DocumentSetup.
//
&AtClient
Procedure DocumentSetup(Command)
	
	// 1. Form parameter structure to fill "Document setting" form.
	ParametersStructure = New Structure;
	ParametersStructure.Insert("WorkKindPositionInWorkTask", 	Object.WorkKindPosition);
	ParametersStructure.Insert("WereMadeChanges", 				False);
	
	StructureDocumentSetting = Undefined;

	
	OpenForm("CommonForm.DocumentSetup", ParametersStructure,,,,, New NotifyDescription("DocumentSettingEnd", ThisObject));
	
EndProcedure

#EndRegion

#Region FormEventsHandlers

&AtServer
// Procedure - OnCreateAtServer event handler.
//
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	DriveServer.FillDocumentHeader(
		Object,
		,
		Parameters.CopyingValue,
		Parameters.Basis,
		PostingIsAllowed,
		Parameters.FillingValues);
	
	If Not ValueIsFilled(DocumentDate) Then
		DocumentDate = CurrentSessionDate();
	EndIf;
	
	ParentCompany = DriveServer.GetCompany(Object.Company);
	
	SetPriceTypesChoiceList();
	
	If Object.Works.Count() = 0 Then
		NewRow = Object.Works.Add();
		If Not ValueIsFilled(Object.Ref)
		   AND Not ValueIsFilled(Parameters.CopyingValue) Then
			If Parameters.FillingValues.Property("Customer")
			   AND ValueIsFilled(Parameters.FillingValues.Customer) Then
				NewRow.Customer = Parameters.FillingValues.Customer;
			EndIf;
			If Parameters.Property("BeginTime") Then 
				NewRow.Day = BegOfDay(Parameters.BeginTime);
				NewRow.BeginTime = Parameters.BeginTime;
			EndIf;
			If Parameters.Property("EndTime") Then 
				NewRow.EndTime = Parameters.EndTime;
			EndIf;
			CalculateDurationAtServer(NewRow);
			
		EndIf;
		Items.Works.CurrentRow = NewRow.GetID();
	Else
		Items.Works.CurrentRow = Object.Works[0].GetID();
	EndIf;
	
	OperationKind = Object.OperationKind;
	
	SetVisibleAndEnabledFromOperationKind();
	
	// Attribute visible set from user settings
	SetVisibleFromUserSettings();
	
	If ValueIsFilled(Object.Ref) Then
		NotifyWorkCalendar = False;
	Else
		NotifyWorkCalendar = True;
	EndIf; 
	DocumentModified = False;
	
	If Not Constants.UseSecondaryEmployment.Get() Then
		If Items.Find("EmployeeCode") <> Undefined Then
			Items.EmployeeCode.Visible = False;
		EndIf;
	EndIf;
	
	If Parameters.Property("Employee") Then // for filling from manager contacts.
		Object.Employee = Parameters.Employee;
	EndIf;
	
	// StandardSubsystems.ObjectVersioning
	ObjectsVersioning.OnCreateAtServer(ThisObject);
	// End StandardSubsystems.ObjectVersioning
	
	// StandardSubsystems.AdditionalReportsAndDataProcessors
	AdditionalReportsAndDataProcessors.OnCreateAtServer(ThisObject);
	// End StandardSubsystems.AdditionalReportsAndDataProcessors
	
	// StandardSubsystems.AttachableCommands
	AttachableCommands.OnCreateAtServer(ThisObject);
	// End StandardSubsystems.AttachableCommands
	
	// StandardSubsystems.Properties
	AdditionalParameters = New Structure;
	AdditionalParameters.Insert("ItemForPlacementName", "GroupAdditionalAttributes");
	PropertyManager.OnCreateAtServer(ThisObject, AdditionalParameters);
	// End StandardSubsystems.Properties
	
EndProcedure

// Procedure - OnReadAtServer event handler.
//
&AtServer
Procedure OnReadAtServer(CurrentObject)
	
	DocumentDate = CurrentObject.Date;
	
	// StandardSubsystems.AttachableCommands
	AttachableCommandsClientServer.UpdateCommands(ThisObject, Object);
	// End StandardSubsystems.AttachableCommands
	
	// StandardSubsystems.EditProhibitionDates
	PeriodClosingDates.ObjectOnReadAtServer(ThisObject, CurrentObject);
	// End StandardSubsystems.EditProhibitionDates
	
	// StandardSubsystems.Properties
	PropertyManager.OnReadAtServer(ThisObject, CurrentObject);
	// End StandardSubsystems.Properties
	
EndProcedure

&AtClient
// Procedure - event handler OnOpen.
//
Procedure OnOpen(Cancel)
	
	// StandardSubsystems.AttachableCommands
	AttachableCommandsClient.StartCommandUpdate(ThisObject);
	// End StandardSubsystems.AttachableCommands
	
	// StandardSubsystems.Properties
	PropertyManagerClient.AfterImportAdditionalAttributes(ThisObject);
	// End StandardSubsystems.Properties
	
	LineCount = Object.Works.Count();
	Items.EditInList.Check = LineCount > 1;
	
	If Items.EditInList.Check Then
		Items.Pages.CurrentPage = Items.List;
	Else
		Items.Pages.CurrentPage = Items.OneRow;
	EndIf;
	
	// Prices precision begin
	PrecisionAppearanceClient.SetPricesAppearance(ThisObject, Object.Company, PricesFields());
	// Prices precision end
	
EndProcedure

&AtClient
// Procedure - event handler AfterWriting.
//
Procedure AfterWrite(WriteParameters)
	
	If DocumentModified Then
		NotifyWorkCalendar = True;
		DocumentModified = False;
	EndIf;
	
EndProcedure

&AtServer
// Procedure-handler of the BeforeWriteAtServer event.
// Performs initial attributes forms filling.
//
Procedure BeforeWriteAtServer(Cancel, CurrentObject, WriteParameters)
	
	If Modified Then
		DocumentModified = True;
	EndIf;
	
	// StandardSubsystems.Properties
	PropertyManager.BeforeWriteAtServer(ThisObject, CurrentObject);
	// End StandardSubsystems.Properties
	
EndProcedure

&AtClient
Procedure NotificationProcessing(EventName, Parameter, Source)
	
	// StandardSubsystems.Properties
	If PropertyManagerClient.ProcessNofifications(ThisObject, EventName, Parameter) Then
		UpdateAdditionalAttributeItems();
		PropertyManagerClient.AfterImportAdditionalAttributes(ThisObject);
	EndIf;
	// End StandardSubsystems.Properties
	
EndProcedure

&AtServer
Procedure FillCheckProcessingAtServer(Cancel, CheckedAttributes)
	
	// StandardSubsystems.Properties
	PropertyManager.FillCheckProcessing(ThisObject, Cancel, CheckedAttributes);
	// End StandardSubsystems.Properties
	
EndProcedure

#EndRegion

#Region FormItemEventsHandlers

&AtClient
// Procedure - event handler OnChange of the Date input field.
// The procedure determines the situation when after changing the date
// of a document this document is found in another period
// of documents enumeration, and in this case the procedure assigns new unique number to the document.
// Overrides the corresponding form parameter.
//
Procedure DateOnChange(Item)
	
	DriveClient.ProcessDateChange(ThisObject, "");
	
EndProcedure

&AtClient
// Procedure - event handler OnChange of the Company input field.
// In procedure the document number is cleared, and also 
// the form functional options are configured.
// Overrides the corresponding form parameter.
//
Procedure CompanyOnChange(Item)

	// Company change event data processor.
	Object.Number = "";
	StructureData = GetCompanyDataOnChange(Object.Company);
	ParentCompany = StructureData.Company;
	
	SetPriceTypesChoiceList();
	
	// Prices precision begin
	PrecisionAppearanceClient.SetPricesAppearance(ThisObject, Object.Company, PricesFields());
	// Prices precision end
	
EndProcedure

&AtClient
// Procedure - event handler OnChange of the OperationKind input field.
//
Procedure OperationKindOnChange(Item)
	
	TypeOfOperationsBeforeChange = OperationKind;
	OperationKind = Object.OperationKind;
	
	If TypeOfOperationsBeforeChange <> OperationKind Then
		SetVisibleAndEnabledFromOperationKind();
	EndIf;
	
EndProcedure

&AtClient
Procedure CommentStartChoice(Item, ChoiceData, StandardProcessing)
	
	CommonClient.ShowCommentEditingForm(Item.EditText, ThisObject);
	
EndProcedure

&AtClient
// Procedure - event handler OnChange input field WorkKind.
//
Procedure WorkKindOnChange(Item)
	
	StructureData = New Structure();
	StructureData.Insert("Company", 		Object.Company);
	StructureData.Insert("ProcessingDate", 	Object.Date);
	StructureData.Insert("Products", 	Object.WorkKind);
	StructureData.Insert("PriceKind", 			Object.PriceKind);	
	
	Price = GetPrice(StructureData).Price;
	
	For Each TSRow In Object.Works Do		
		TSRow.Price = Price;
		CalculateAmount(TSRow);		
	EndDo;
	
EndProcedure

&AtClient
// Procedure - event handler OnChange of the PriceKind input field.
//
Procedure PricesKindOnChange(Item)
	
	DataStructure = New Structure;
	DocumentTabularSection = New Array;

	DataStructure.Insert("Date",				Object.Date);
	DataStructure.Insert("Company",			Counterparty);
	DataStructure.Insert("PriceKind",				Object.PriceKind);
	
	If WorkKindInHeader Then
	
		TabularSectionRow = New Structure();
		TabularSectionRow.Insert("Products",		Object.WorkKind);
		TabularSectionRow.Insert("Price",				0);
		
		DocumentTabularSection.Add(TabularSectionRow);
	
	Else
	
		For Each TSRow In Object.Works Do
			
			TSRow.Price = 0;
			
			TabularSectionRow = New Structure();
			TabularSectionRow.Insert("Products",		TSRow.WorkKind);
			TabularSectionRow.Insert("Price",				0);
			
			DocumentTabularSection.Add(TabularSectionRow);
			
		EndDo;		
	
	EndIf;
		
	GetTabularSectionPricesByPriceKind(DataStructure, DocumentTabularSection);
	
	If WorkKindInHeader Then
		
		Price = DocumentTabularSection[0].Price;
		
		For Each TSRow In Object.Works Do		
			TSRow.Price = Price;
			CalculateAmount(TSRow);		
		EndDo;
	
	Else
	
		For Each TSRow In DocumentTabularSection Do

			SearchStructure = New Structure;
			SearchStructure.Insert("WorkKind", TSRow.Products);
			
			SearchResult = Object.Works.FindRows(SearchStructure);
			
			For Each ResultRow In SearchResult Do				
				ResultRow.Price = TSRow.Price;
				CalculateAmount(ResultRow);				
			EndDo;
			
		EndDo;		
	
	EndIf;
	
EndProcedure

&AtClient
// Procedure - event handler OnStartEdit tabular section Works.
//
Procedure WorksOnStartEdit(Item, NewRow, Copy)
	
	If NewRow AND Not Copy Then
		
		If WorkKindInHeader Then
	
			CurrentRow = Items.Works.CurrentData;
			
			StructureData = New Structure();
			StructureData.Insert("Company", 		Object.Company);
			StructureData.Insert("ProcessingDate", 	Object.Date);
			StructureData.Insert("Products", 	Object.WorkKind);
			StructureData.Insert("PriceKind", 			Object.PriceKind);	
			
			CurrentRow.Price = GetPrice(StructureData).Price;
			
			CalculateAmount(CurrentRow);
		
		EndIf;
		
	EndIf;
	
EndProcedure

&AtClient
// Procedure - event handler OnChange input field WorkKind.
//
Procedure WorksWorkKindOnChange(Item)
	
	CurrentRow = Items.Works.CurrentData;
	
	StructureData = New Structure();
	StructureData.Insert("Company", 		Object.Company);
	StructureData.Insert("ProcessingDate", 	CurrentRow.Day);
	StructureData.Insert("Products", 	CurrentRow.WorkKind);
	StructureData.Insert("PriceKind", 			Object.PriceKind);	
	
	CurrentRow.Price = GetPrice(StructureData).Price;
	
	CalculateAmount(CurrentRow);
	
EndProcedure

&AtClient
// Procedure - handler of event OnChange of input field StartTime.
//
Procedure WorksBeginTimeOnChange(Item)
	
	CurrentRow = Items.Works.CurrentData;
	
	If CurrentRow.BeginTime > CurrentRow.EndTime Then
		CurrentRow.EndTime = CurrentRow.BeginTime;
	EndIf;
	
	CalculateDuration(CurrentRow);
	CalculateAmount(CurrentRow);
	
	If ValueIsFilled(CurrentRow.BeginTime)
		AND Not ValueIsFilled(CurrentRow.Day) Then
		
		CurrentRow.Day = CommonClient.SessionDate();
		
	EndIf;
	
EndProcedure

&AtClient
// Procedure - handler of event OnChange of input field EndTime.
//
Procedure WorksEndTimeOnChange(Item)
	
	CurrentRow = Items.Works.CurrentData;
	
	If CurrentRow.BeginTime > CurrentRow.EndTime Then
		CurrentRow.BeginTime = CurrentRow.EndTime;
	EndIf; 
	
	CalculateDuration(CurrentRow);
	CalculateAmount(CurrentRow);
	
	If ValueIsFilled(CurrentRow.EndTime)
		AND Not ValueIsFilled(CurrentRow.Day) Then
		
		CurrentRow.Day = CommonClient.SessionDate();
		
	EndIf;
	
EndProcedure

&AtClient
// Procedure - event handler OnChange of the Price input field.
//
Procedure WorksPriceOnChange(Item)
	
	CurrentRow = Items.Works.CurrentData;
	
	CalculateAmount(CurrentRow);
	
EndProcedure

&AtClient
// Procedure - event handler OnChange of the Amount input field.
//
Procedure WorksAmountOnChange(Item)
	
	CurrentRow = Items.Works.CurrentData;
	
	CurrentRow.Price = ?(CurrentRow.DurationInHours = 0, 0, CurrentRow.Amount / CurrentRow.DurationInHours);
	
EndProcedure

&AtClient
// Procedure - event handler OnChange input field Duration.
//
Procedure WorksDurationOnChange(Item)
	
	CurrentRow = Items.Works.CurrentData;
	
	DurationInSeconds = Hour(CurrentRow.Duration) * 3600 + Minute(CurrentRow.Duration) * 60 + Second(CurrentRow.Duration);	
	CurrentRow.EndTime = CurrentRow.BeginTime + DurationInSeconds;
	
	If '00010101235959' - CurrentRow.BeginTime < DurationInSeconds Then	
		CurrentRow.EndTime = '00010101235959';
		CalculateDuration(CurrentRow);		
	EndIf;
	
	CalculateDurationInHours(CurrentRow);
	CalculateAmount(CurrentRow);
	
	If ValueIsFilled(CurrentRow.Duration)
		AND Not ValueIsFilled(CurrentRow.Day) Then
		
		CurrentRow.Day = CommonClient.SessionDate();
		
	EndIf;
	
EndProcedure

&AtClient
// Procedure - event handler OnChange of the Day attribute.
//
Procedure WorksDayOnChange(Item)
	
	CurrentRow = Items.Works.CurrentData;
	If ValueIsFilled(CurrentRow.Day)
		AND CurrentRow.BeginTime = BegOfDay(CurrentRow.BeginTime)
		AND CurrentRow.BeginTime = CurrentRow.EndTime Then
		
		CurrentRow.EndTime = EndOfDay(CurrentRow.EndTime) - 59;
		
	ElsIf Not ValueIsFilled(CurrentRow.Day) Then
		
		CurrentRow.BeginTime = '00010101';
		CurrentRow.EndTime = '00010101';
		CurrentRow.Duration = '00010101';
		CurrentRow.DurationInHours = 0;
		
	EndIf;
	
EndProcedure

&AtClient
// Procedure - event handler ChoiceProcessing of attribute Customer.
//
Procedure WorksConsumerChoiceProcessingChoice(Item, ValueSelected, StandardProcessing)
	
	If ValueSelected = Type("CatalogRef.CounterpartyContracts") Then
	
		StandardProcessing = False;
		
		SelectedContract = Undefined;

		
		OpenForm("Catalog.CounterpartyContracts.Form.ChoiceFormWithCounterparty",,,,,, New NotifyDescription("WorkCustomerSelectionDataProcessorEnd", ThisObject));
	
	EndIf;
	
EndProcedure

&AtClient
Procedure WorkCustomerSelectionDataProcessorEnd(Result, AdditionalParameters) Export
    
    SelectedContract = Result;
    
    If TypeOf(SelectedContract) = Type("CatalogRef.CounterpartyContracts")Then
        CurrentRow = Items.Works.CurrentData;	
        CurrentRow.Customer = SelectedContract;
    EndIf;

EndProcedure

&AtClient
// Procedure - event handler StartChoice of the Comment attribute of the Work tabular section.
//
Procedure WorksCommentStartChoice(Item, ChoiceData, StandardProcessing)
	
	StandardProcessing = False;
	
	CurrentData = Items.Works.CurrentData;
	FormParameters = New Structure("Text, Title", CurrentData.Comment, "Comment edit");  
	ReturnComment = Undefined;
  
	OpenForm("CommonForm.TextEdit", FormParameters,,,,, New NotifyDescription("WorkCommentSelectionStartEnd", ThisObject, New Structure("CurrentData", CurrentData))); 
	
EndProcedure

&AtClient
Procedure WorkCommentSelectionStartEnd(Result, AdditionalParameters) Export
    
    CurrentData = AdditionalParameters.CurrentData;
    
    
    ReturnComment = Result;
    
    If TypeOf(ReturnComment) = Type("String") Then
        
        If CurrentData.Comment <> ReturnComment Then
            Modified = True;
        EndIf;
        
        CurrentData.Comment = ReturnComment;
        
    EndIf;

EndProcedure

&AtClient
Procedure BeforeClose(Cancel, Exit, WarningText, StandardProcessing)
	
	FilesOperationsClient.ShowConfirmationForClosingFormWithFiles(ThisObject, Cancel, Exit, Object.Ref);
	
	If Cancel Then
		Return;
	EndIf;
	
	If NotifyWorkCalendar Then
		Notify("TaskChanged", Object.Employee);
	EndIf;
	
EndProcedure

#EndRegion

#Region ActionsResultsHandlers

&AtClient
Procedure DocumentSettingEnd(Result, AdditionalParameters) Export
	
	// 2. Open the form "Prices and Currency".
	StructureDocumentSetting = Result;
	
	// 3. Apply changes made in "Document setting" form.
	If TypeOf(StructureDocumentSetting) = Type("Structure") AND StructureDocumentSetting.WereMadeChanges Then
		
		Object.WorkKindPosition = StructureDocumentSetting.WorkKindPositionInWorkTask;
		SetVisibleFromUserSettings();
		
		Modified = True;
		
	EndIf;
	
EndProcedure

#EndRegion

#Region LibrariesHandlers

// StandardSubsystems.AttachableCommands
&AtClient
Procedure Attachable_ExecuteCommand(Command)
	AttachableCommandsClient.ExecuteCommand(ThisObject, Command, Object);
EndProcedure

&AtServer
Procedure Attachable_ExecuteCommandAtServer(Context, Result)
	AttachableCommands.ExecuteCommand(ThisObject, Context, Object, Result);
EndProcedure

&AtClient
Procedure Attachable_UpdateCommands()
	AttachableCommandsClientServer.UpdateCommands(ThisObject, Object);
EndProcedure
// End StandardSubsystems.AttachableCommands

// StandardSubsystems.Properties

&AtClient
Procedure Attachable_PropertiesExecuteCommand(ItemOrCommand, URL = Undefined, StandardProcessing = Undefined)
	PropertyManagerClient.ExecuteCommand(ThisObject, ItemOrCommand, StandardProcessing);
EndProcedure

&AtClient
Procedure UpdateAdditionalAttributesDependencies()
	PropertyManagerClient.UpdateAdditionalAttributesDependencies(ThisObject);
EndProcedure

&AtClient
Procedure Attachable_OnChangeAdditionalAttribute(Item)
	PropertyManagerClient.UpdateAdditionalAttributesDependencies(ThisObject);
EndProcedure

&AtServer
Procedure UpdateAdditionalAttributeItems()
	PropertyManager.UpdateAdditionalAttributesItems(ThisObject);
EndProcedure

// End StandardSubsystems.Properties

#EndRegion