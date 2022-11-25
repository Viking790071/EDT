#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region Public

// Initializes the tables of values that contain the data of the document table sections.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
Procedure InitializeDocumentData(DocumentRefTransferOrder, StructureAdditionalProperties) Export

	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	Query.Text =
	"SELECT
	|	TransferOrder.Ref AS Ref,
	|	TransferOrder.Closed AS Closed,
	|	TransferOrder.Date AS Date,
	|	TransferOrder.OrderState AS OrderState,
	|	TransferOrder.StructuralUnit AS StructuralUnit
	|INTO Header
	|FROM
	|	Document.TransferOrder AS TransferOrder
	|WHERE
	|	TransferOrder.Ref = &Ref
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	TransferOrderInventory.LineNumber AS LineNumber,
	|	TransferOrder.Date AS Period,
	|	VALUE(AccumulationRecordType.Receipt) AS RecordType,
	|	&Company AS Company,
	|	TransferOrderInventory.Ref AS TransferOrder,
	|	TransferOrderInventory.Products AS Products,
	|	CASE
	|		WHEN &UseCharacteristics
	|			THEN TransferOrderInventory.Characteristic
	|		ELSE VALUE(Catalog.ProductsCharacteristics.EmptyRef)
	|	END AS Characteristic,
	|	CASE
	|		WHEN VALUETYPE(TransferOrderInventory.MeasurementUnit) = TYPE(Catalog.UOMClassifier)
	|			THEN TransferOrderInventory.Quantity
	|		ELSE TransferOrderInventory.Quantity * TransferOrderInventory.MeasurementUnit.Factor
	|	END AS Quantity,
	|	TransferOrderInventory.ShipmentDate AS ShipmentDate
	|FROM
	|	Document.TransferOrder.Inventory AS TransferOrderInventory
	|		INNER JOIN Header AS TransferOrder
	|			LEFT JOIN Catalog.TransferOrderStatuses AS TransferOrderStatuses
	|			ON TransferOrder.OrderState = TransferOrderStatuses.Ref
	|		ON TransferOrderInventory.Ref = TransferOrder.Ref
	|WHERE
	|	(TransferOrderStatuses.OrderStatus = VALUE(Enum.OrderStatuses.InProcess)
	|				AND NOT TransferOrder.Closed
	|			OR TransferOrderStatuses.OrderStatus = VALUE(Enum.OrderStatuses.Completed))
	|
	|ORDER BY
	|	LineNumber
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	1 AS Ordering,
	|	TransferOrderInventory.LineNumber AS LineNumber,
	|	TransferOrderInventory.ShipmentDate AS Period,
	|	&Company AS Company,
	|	VALUE(Enum.InventoryMovementTypes.Shipment) AS MovementType,
	|	TransferOrderInventory.Ref AS Order,
	|	TransferOrderInventory.Products AS Products,
	|	CASE
	|		WHEN &UseCharacteristics
	|			THEN TransferOrderInventory.Characteristic
	|		ELSE VALUE(Catalog.ProductsCharacteristics.EmptyRef)
	|	END AS Characteristic,
	|	CASE
	|		WHEN VALUETYPE(TransferOrderInventory.MeasurementUnit) = TYPE(Catalog.UOMClassifier)
	|			THEN TransferOrderInventory.Quantity
	|		ELSE TransferOrderInventory.Quantity * TransferOrderInventory.MeasurementUnit.Factor
	|	END AS Quantity
	|FROM
	|	Document.TransferOrder.Inventory AS TransferOrderInventory
	|		INNER JOIN Header AS TransferOrder
	|			LEFT JOIN Catalog.TransferOrderStatuses AS TransferOrderStatuses
	|			ON TransferOrder.OrderState = TransferOrderStatuses.Ref
	|		ON TransferOrderInventory.Ref = TransferOrder.Ref
	|WHERE
	|	(TransferOrderStatuses.OrderStatus = VALUE(Enum.OrderStatuses.InProcess)
	|				AND TransferOrder.Closed = FALSE
	|			OR TransferOrderStatuses.OrderStatus = VALUE(Enum.OrderStatuses.Completed))
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	TransferOrderInventory.LineNumber AS LineNumber,
	|	TransferOrder.Date AS Period,
	|	&Company AS Company,
	|	TransferOrder.StructuralUnit AS StructuralUnit,
	|	CASE
	|		WHEN &UseDefaultTypeOfAccounting
	|			THEN TransferOrderInventory.InventoryGLAccount
	|		ELSE VALUE(ChartOfAccounts.PrimaryChartOfAccounts.EmptyRef)
	|	END AS GLAccount,
	|	TransferOrderInventory.Products AS Products,
	|	CASE
	|		WHEN &UseCharacteristics
	|			THEN TransferOrderInventory.Characteristic
	|		ELSE VALUE(Catalog.ProductsCharacteristics.EmptyRef)
	|	END AS Characteristic,
	|	CASE
	|		WHEN &UseBatches
	|			THEN TransferOrderInventory.Batch
	|		ELSE VALUE(Catalog.ProductsBatches.EmptyRef)
	|	END AS Batch,
	|	TransferOrderInventory.Ref AS TransferOrder,
	|	CASE
	|		WHEN VALUETYPE(TransferOrderInventory.MeasurementUnit) = TYPE(Catalog.UOMClassifier)
	|			THEN TransferOrderInventory.Reserve
	|		ELSE TransferOrderInventory.Reserve * TransferOrderInventory.MeasurementUnit.Factor
	|	END AS Quantity
	|INTO TemporaryTableInventory
	|FROM
	|	Document.TransferOrder.Inventory AS TransferOrderInventory
	|		LEFT JOIN Header AS TransferOrder
	|			LEFT JOIN Catalog.TransferOrderStatuses AS TransferOrderStatuses
	|			ON TransferOrder.OrderState = TransferOrderStatuses.Ref
	|		ON TransferOrderInventory.Ref = TransferOrder.Ref
	|WHERE
	|	TransferOrderInventory.Reserve > 0
	|	AND (TransferOrderStatuses.OrderStatus = VALUE(Enum.OrderStatuses.InProcess)
	|				AND TransferOrder.Closed = FALSE
	|			OR TransferOrderStatuses.OrderStatus = VALUE(Enum.OrderStatuses.Completed))";
	
	MainLanguageCode = CommonClientServer.DefaultLanguageCode();
	
	Query.SetParameter("Ref",					DocumentRefTransferOrder);
	Query.SetParameter("PointInTime",			New Boundary(StructureAdditionalProperties.ForPosting.PointInTime, BoundaryType.Including));
	Query.SetParameter("Company",				StructureAdditionalProperties.ForPosting.Company);
	Query.SetParameter("UseCharacteristics",	StructureAdditionalProperties.AccountingPolicy.UseCharacteristics);
	Query.SetParameter("UseBatches",			StructureAdditionalProperties.AccountingPolicy.UseBatches);
	Query.SetParameter("UseDefaultTypeOfAccounting", GetFunctionalOption("UseDefaultTypeOfAccounting"));
	
	ResultsArray = Query.ExecuteBatch();
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableTransferOrders", ResultsArray[1].Unload());
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableInventoryFlowCalendar", ResultsArray[2].Unload());
	
	GenerateTableReservedProducts(DocumentRefTransferOrder, StructureAdditionalProperties);
	
EndProcedure

// Controls the occurrence of negative balances.
//
Procedure RunControl(DocumentRefTransferOrder, AdditionalProperties, Cancel, PostingDelete = False) Export
	
	If Not DriveServer.RunBalanceControl() Then
		Return;
	EndIf;
	
	StructureTemporaryTables = AdditionalProperties.ForPosting.StructureTemporaryTables;
	
	// If the "RegisterRecordsTransferOrdersChange" or "RegisterRecordsReservedProductsChange"
	// temporary tables contain records, execute the control of balances.
	
	If StructureTemporaryTables.RegisterRecordsReservedProductsChange
		OR StructureTemporaryTables.RegisterRecordsTransferOrdersChange Then
		
		Query = New Query;
		Query.Text = GenerateQueryTextBalancesTransferOrders(); // [0]
		Query.Text = Query.Text + AccumulationRegisters.ReservedProducts.BalancesControlQueryText();
		
		Query.TempTablesManager = StructureTemporaryTables.TempTablesManager;
		Query.SetParameter("ControlTime", AdditionalProperties.ForPosting.ControlTime);
		
		ResultsArray = Query.ExecuteBatch();
		
		If NOT ResultsArray[0].IsEmpty() OR NOT ResultsArray[1].IsEmpty()Then
			DocumentObjectTransferOrder = DocumentRefTransferOrder.GetObject();
		EndIf;
		
		// Negative balance on transfer order.
		If Not ResultsArray[0].IsEmpty() Then
			QueryResultSelection = ResultsArray[0].Select();
			DriveServer.ShowMessageAboutPostingToTransferOrdersRegisterErrors(DocumentObjectTransferOrder, QueryResultSelection, Cancel);
		EndIf;
		
		// Negative balance of need for reserved products.
		If Not ResultsArray[1].IsEmpty() Then
			QueryResultSelection = ResultsArray[1].Select();
			DriveServer.ShowMessageAboutPostingToReservedProductsRegisterErrors(DocumentObjectTransferOrder, QueryResultSelection, Cancel);
		EndIf;
		
		DriveServer.CheckAvailableStockBalance(DocumentObjectTransferOrder, AdditionalProperties, Cancel);
		
		DriveServer.CheckOrderedMinusBackorderedBalance(DocumentRefTransferOrder, AdditionalProperties, Cancel);
		
	EndIf;
	
EndProcedure

// Checks the possibility of input on the basis.
//
Procedure CheckAbilityOfEnteringByTransferOrder(FillingData, AttributeValues) Export
	
	If AttributeValues.Property("Posted") Then
		If Not AttributeValues.Posted Then
			ErrorText = StringFunctionsClientServer.SubstituteParametersToString(
						NStr("en = '%1 is not posted. Cannot use it as a base document. Please, post it first.'; ru = 'Документ %1 не проведен. Ввод на основании непроведенного документа запрещен.';pl = '%1 dokument nie został zatwierdzony. Nie można użyć go jako dokumentu źródłowego. Najpierw zatwierdź go.';es_ES = '%1 no se ha enviado. No se puede utilizarlo como un documento de base. Por favor, enviarlo primero.';es_CO = '%1 no se ha enviado. No se puede utilizarlo como un documento de base. Por favor, enviarlo primero.';tr = '%1 kaydedilmediğinden temel belge olarak kullanılamıyor. Lütfen, önce kaydedin.';it = '%1 non pubblicato. Non è possibile utilizzarlo come documento di base. Si prega di pubblicarlo prima di tutto.';de = '%1 wird nicht gebucht. Kann nicht als Basisdokument verwendet werden. Zuerst bitte buchen.'"),
						FillingData);
			Raise ErrorText;
		EndIf;
	EndIf;
	
	If AttributeValues.Property("OrderState") Then
		
		If AttributeValues.OrderState.OrderStatus = Enums.OrderStatuses.Open Then
			ErrorText = StringFunctionsClientServer.SubstituteParametersToString(
						NStr("en = 'The status of %1 is %2. Cannot use it as a base document.'; ru = 'Документ %1 в состоянии %2. Ввод на основании запрещен.';pl = 'Ma %1 status %2. Nie można użyć go, jako dokumentu źródłowego.';es_ES = 'El estado de %1 es %2. No se puede utilizarlo como un documento de base.';es_CO = 'El estado de %1 es %2. No se puede utilizarlo como un documento de base.';tr = '%1 öğesinin durumu: %2. Temel belge olarak kullanılamaz.';it = 'Lo stato di %1 è %2. Non è possibile usarlo come documento di base.';de = 'Der Status von %1 ist %2. Kann nicht als Basisdokument verwendet werden.'"),
						FillingData, 
						AttributeValues.OrderState);
			Raise ErrorText;
			
		ElsIf AttributeValues.OrderState.OrderStatus = Enums.OrderStatuses.Completed Then
			ErrorText  = StringFunctionsClientServer.SubstituteParametersToString(
						NStr("en = '%1 is completed. Cannot use a completed order as a base document.'; ru = '%1 закрыт (выполнен). Ввод на основании закрытого заказа запрещен.';pl = '%1 jest zamknięty. Nie można użyć zamkniętego zamówienia jako dokumentu źródłowego.';es_ES = '%1 se ha finalizado. No se puede utilizarlo un orden finalizado como un documento de base.';es_CO = '%1 se ha finalizado. No se puede utilizarlo un orden finalizado como un documento de base.';tr = '%1 tamamlandı. Tamamlanmış bir siparişi temel belge olarak kullanamazsınız.';it = '%1 è completato. Non è possibile usare un ordine completato come documento base.';de = '%1 ist abgeschlossen. Ein abgeschlossener Auftrag kann nicht als Basisdokument verwendet werden.'"),
						FillingData);
			Raise ErrorText;
	
		EndIf;
		
	EndIf;
	
EndProcedure

#Region LibrariesHandlers

#Region PrintInterface

// Generate printed forms of objects
//
// Incoming:
//   TemplateNames    - String    - Names of layouts separated
//   by commas ObjectsArray  - Array    - Array of refs to objects that
//   need to be printed PrintParameters - Structure - Structure of additional printing parameters
//
// Outgoing:
//   PrintFormsCollection - Values table - Generated
//   table documents OutputParameters       - Structure        - Parameters of generated table documents
//
Procedure Print(ObjectsArray, PrintParameters, PrintFormsCollection, PrintObjects, OutputParameters) Export
	
		If PrintManagement.TemplatePrintRequired(PrintFormsCollection, "TransferOrderPrintForm") Then
			PrintManagement.OutputSpreadsheetDocumentToCollection(
				PrintFormsCollection, 
				"TransferOrderPrintForm",
				NStr("en = 'Transfer order'; ru = 'Заказ на перемещение';pl = 'Zamówienie przeniesienia';es_ES = 'Orden de transferencia';es_CO = 'Orden de transferencia';tr = 'Transfer emri';it = 'Ordine trasferimento';de = 'Transportauftrag'"),
				PrintForm(ObjectsArray, PrintObjects, "TransferOrderPrintForm", PrintParameters.Result));
		EndIf;

	// parameters of sending printing forms by email
	DriveServer.FillSendingParameters(OutputParameters.SendOptions, ObjectsArray, PrintFormsCollection);
	
EndProcedure

// Fills in the list of printing commands.
// 
// Parameters:
//   PrintCommands - ValueTable - see fields' content in the PrintManagement.CreatePrintCommandsCollection function.
//
Procedure AddPrintCommands(PrintCommands) Export
	PrintCommand = PrintCommands.Add();
	PrintCommand.ID							= "TransferOrderPrintForm";
	PrintCommand.Presentation				= NStr("en = 'Transfer order'; ru = 'Заказ на перемещение';pl = 'Zamówienie przeniesienia';es_ES = 'Orden de transferencia';es_CO = 'Orden de transferencia';tr = 'Transfer emri';it = 'Ordine trasferimento';de = 'Transportauftrag'");
	PrintCommand.CheckPostingBeforePrint	= False;
	PrintCommand.Order						= 1;	
EndProcedure

#EndRegion

#Region ObjectVersioning

// StandardSubsystems.ObjectVersioning

Procedure OnDefineObjectVersioningSettings(Settings) Export

EndProcedure

// End StandardSubsystems.ObjectVersioning

#EndRegion

#EndRegion

#Region GLAccounts

Function GetGLAccountsStructure(StructureData) Export

	ObjectParameters = StructureData.ObjectParameters;
	GLAccountsForFilling = New Structure;
	
	GLAccountsForFilling.Insert("InventoryGLAccount", StructureData.InventoryGLAccount);
	
	Return GLAccountsForFilling;
	
EndFunction

#EndRegion

#Region IncomeAndExpenseItemsInDocuments

Function GetIncomeAndExpenseItemsStructure(StructureData) Export
	
	Return New Structure;
	
EndFunction

Function GetIncomeAndExpenseItemsGLAMap(StructureData) Export

	Return New Structure;
	
EndFunction

#EndRegion


#EndRegion

#Region Internal

Function GetTransferOrderStringStatuses() Export
	
	StatusesStructure = New Structure;
	StatusesStructure.Insert("StatusInProcess", NStr("en = 'In process'; ru = 'В работе';pl = 'W toku';es_ES = 'En proceso';es_CO = 'En proceso';tr = 'İşlemde';it = 'In corso';de = 'In Bearbeitung'"));
	StatusesStructure.Insert("StatusCompleted", NStr("en = 'Completed'; ru = 'Завершен';pl = 'Zakończono';es_ES = 'Finalizado';es_CO = 'Finalizado';tr = 'Tamamlandı';it = 'Completato';de = 'Abgeschlossen'"));
	StatusesStructure.Insert("StatusCanceled", NStr("en = 'Canceled'; ru = 'Отменен';pl = 'Anulowano';es_ES = 'Cancelado';es_CO = 'Cancelado';tr = 'İptal edildi';it = 'Annullati';de = 'Abgebrochen'"));
	
	Return StatusesStructure;
	
EndFunction

#EndRegion

#Region Private

// Function returns query text by the balance of TransferOrders register.
//
Function GenerateQueryTextBalancesTransferOrders()
	
	QueryText =
	"SELECT
	|	RegisterRecordsTransferOrdersChange.LineNumber AS LineNumber,
	|	RegisterRecordsTransferOrdersChange.Company AS CompanyPresentation,
	|	RegisterRecordsTransferOrdersChange.TransferOrder AS OrderPresentation,
	|	RegisterRecordsTransferOrdersChange.Products AS ProductsPresentation,
	|	RegisterRecordsTransferOrdersChange.Characteristic AS CharacteristicPresentation,
	|	TransferOrdersBalances.Products.MeasurementUnit AS MeasurementUnitPresentation,
	|	ISNULL(RegisterRecordsTransferOrdersChange.QuantityChange, 0) + ISNULL(TransferOrdersBalances.QuantityBalance, 0) AS BalanceTransferOrders,
	|	ISNULL(TransferOrdersBalances.QuantityBalance, 0) AS QuantityBalanceTransferOrders
	|FROM
	|	RegisterRecordsTransferOrdersChange AS RegisterRecordsTransferOrdersChange
	|		INNER JOIN AccumulationRegister.TransferOrders.Balance(&ControlTime, ) AS TransferOrdersBalances
	|		ON RegisterRecordsTransferOrdersChange.Company = TransferOrdersBalances.Company
	|			AND RegisterRecordsTransferOrdersChange.TransferOrder = TransferOrdersBalances.TransferOrder
	|			AND RegisterRecordsTransferOrdersChange.Products = TransferOrdersBalances.Products
	|			AND RegisterRecordsTransferOrdersChange.Characteristic = TransferOrdersBalances.Characteristic
	|			AND (ISNULL(TransferOrdersBalances.QuantityBalance, 0) < 0)
	|
	|ORDER BY
	|	LineNumber";
	
	Return QueryText + DriveClientServer.GetQueryDelimeter();
	
EndFunction

// Generates a table of values that contains the data for the register.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
Procedure GenerateTableReservedProducts(DocumentRefTransferOrder, StructureAdditionalProperties)
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	Query.Text =
	"SELECT
	|	Table.LineNumber AS LineNumber,
	|	VALUE(AccumulationRecordType.Receipt) AS RecordType,
	|	Table.Period AS Period,
	|	Table.Company AS Company,
	|	Table.StructuralUnit AS StructuralUnit,
	|	Table.GLAccount AS GLAccount,
	|	Table.Products AS Products,
	|	Table.Characteristic AS Characteristic,
	|	Table.Batch AS Batch,
	|	Table.TransferOrder AS SalesOrder,
	|	Table.Quantity AS Quantity
	|FROM
	|	TemporaryTableInventory AS Table
	|";
	
	QueryResult = Query.Execute();
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableReservedProducts", QueryResult.Unload());
	
EndProcedure

#Region PrivatePrintInterface

// Function checks if the document is
// posted and calls the procedure of document printing.
//
Function PrintForm(ObjectsArray, PrintObjects, TemplateName, PrintParams = Undefined)
	
	
	SpreadsheetDocument = New SpreadsheetDocument;
	SpreadsheetDocument.PrintParametersKey = "PrintParameters_TransferOrder";
	
	FirstDocument = True;
	
	For Each CurrentDocument In ObjectsArray Do
		
		If Not FirstDocument Then
			SpreadsheetDocument.PutHorizontalPageBreak();
		EndIf;
		
		FirstDocument = False;
		FirstLineNumber = SpreadsheetDocument.TableHeight + 1;
		
		Query = New Query();
		Query.SetParameter("CurrentDocument", CurrentDocument);
		
		IsInventoryWriteOff = False;
		
		If TemplateName = "TransferOrderPrintForm" Then
			
			Query.Text = GetTransferOrderQuery();
			
			// MultilingualSupport
			If PrintParams = Undefined Then
				LanguageCode = NationalLanguageSupportClientServer.DefaultLanguageCode();
			Else
				LanguageCode = PrintParams.LanguageCode;
			EndIf;
			
			If LanguageCode <> CurrentLanguage().LanguageCode Then 
				SessionParameters.LanguageCodeForOutput = LanguageCode;
			EndIf;
			
			DriveServer.ChangeQueryTextForCurrentLanguage(Query.Text, LanguageCode);
			// End MultilingualSupport
			
			ResultArray = Query.ExecuteBatch();
			Header = ResultArray[4].Select(QueryResultIteration.ByGroupsWithHierarchy);
			
			While Header.Next() Do
				
				SpreadsheetDocument.PrintParametersName = "PRINT_PARAMETERS_TransferOrder";
				
				Template = PrintManagement.PrintFormTemplate("Document.TransferOrder.PF_MXL_TransferOrder", LanguageCode);
				
				#Region PrintDeliveryNoteTitleArea
				
				TitleArea = Template.GetArea("Title");
				TitleArea.Parameters.Fill(Header);
				
				DocumentMetadata = Header.Ref.Metadata();
				DocumentType = DocumentMetadata.ExtendedObjectPresentation;
				If IsBlankString(DocumentType) Then
					DocumentType = DocumentMetadata.ObjectPresentation;
				EndIf;
				If IsBlankString(DocumentType) Then
					DocumentType = DocumentMetadata.Presentation();
				EndIf;
				
				TitleArea.Parameters.DocumentType = DocumentType;
				
				If ValueIsFilled(Header.CompanyLogoFile) Then
					
					PictureData = AttachedFiles.GetBinaryFileData(Header.CompanyLogoFile);
					If ValueIsFilled(PictureData) Then
						TitleArea.Drawings.Logo.Picture = New Picture(PictureData);
					EndIf;
					
				Else
					TitleArea.Drawings.Delete(TitleArea.Drawings.Logo);
				EndIf;
				
				SpreadsheetDocument.Put(TitleArea);
				
				#EndRegion
				
				#Region PrintDeliveryNoteCompanyInfoArea
				
				CompanyInfoArea = Template.GetArea("CompanyInfo");
				
				InfoAboutCompany = DriveServer.InfoAboutLegalEntityIndividual(
					Header.Company,
					Header.DocumentDate,
					,
					,
					,
					LanguageCode);
				CompanyInfoArea.Parameters.Fill(InfoAboutCompany);
				BarcodesInPrintForms.AddBarcodeToTableDocument(CompanyInfoArea, Header.Ref);
				SpreadsheetDocument.Put(CompanyInfoArea);
				
				#EndRegion
				
				#Region PrintDeliveryNoteFromToInfoArea
				
				FromToInfoArea = Template.GetArea("FromTo");
				FromToInfoArea.Parameters.FullDescrFrom = GetFullDescription(Header.FieldFrom, Header.DocumentDate);
				
				If IsInventoryWriteOff Then
					FromToInfoArea.Parameters.FullDescrTo = Header.FieldTo;
				Else
					FromToInfoArea.Parameters.FullDescrTo = GetFullDescription(Header.FieldTo, Header.DocumentDate);
				EndIf;
				
				SpreadsheetDocument.Put(FromToInfoArea);
				
				#EndRegion
				
				#Region PrintDeliveryNoteCommentArea
				
				CommentArea = Template.GetArea("Comment");
				CommentArea.Parameters.Fill(Header);
				SpreadsheetDocument.Put(CommentArea);
				
				#EndRegion
				
				#Region PrintDeliveryNoteLinesArea
				
				LineHeaderArea = Template.GetArea("LineHeader");
				SpreadsheetDocument.Put(LineHeaderArea);
				
				LineSectionArea	= Template.GetArea("LineSection");
				SeeNextPageArea	= Template.GetArea("SeeNextPage");
				EmptyLineArea	= Template.GetArea("EmptyLine");
				PageNumberArea	= Template.GetArea("PageNumber");
				
				PageNumber = 0;
				
				TabSelection = Header.Select();
				While TabSelection.Next() Do
					
					LineSectionArea.Parameters.Fill(TabSelection);
					LineSectionArea.Parameters.ProductDescription = LineSectionArea.Parameters.ProductDescription 
					+ ?(TabSelection.Characteristic = Catalogs.ProductsCharacteristics.EmptyRef(), "", " (" + TabSelection.Characteristic.Description +")");
					
					AreasToBeChecked = New Array;
					AreasToBeChecked.Add(LineSectionArea);
					AreasToBeChecked.Add(PageNumberArea);
					
					If Common.SpreadsheetDocumentFitsPage(SpreadsheetDocument, AreasToBeChecked) Then
						SpreadsheetDocument.Put(LineSectionArea);
					Else
						
						SpreadsheetDocument.Put(SeeNextPageArea);
						
						AreasToBeChecked.Clear();
						AreasToBeChecked.Add(EmptyLineArea);
						AreasToBeChecked.Add(PageNumberArea);
						
						For i = 1 To 50 Do
							
							If Not Common.SpreadsheetDocumentFitsPage(SpreadsheetDocument, AreasToBeChecked) Or i = 50 Then
								
								PageNumber = PageNumber + 1;
								PageNumberArea.Parameters.PageNumber = PageNumber;
								SpreadsheetDocument.Put(PageNumberArea);
								Break;
								
							Else
								SpreadsheetDocument.Put(EmptyLineArea);
							EndIf;
							
						EndDo;
						
						SpreadsheetDocument.PutHorizontalPageBreak();
						SpreadsheetDocument.Put(TitleArea);
						SpreadsheetDocument.Put(LineHeaderArea);
						SpreadsheetDocument.Put(LineSectionArea);
						
					EndIf;
					
				EndDo;
				
				#EndRegion
				
				#Region PrintDeliveryNoteTotalsArea
				
				LineTotalArea = Template.GetArea("LineTotal");
				LineTotalArea.Parameters.Fill(Header);
				SpreadsheetDocument.Put(LineTotalArea);
				
				AreasToBeChecked.Clear();
				AreasToBeChecked.Add(EmptyLineArea);
				AreasToBeChecked.Add(PageNumberArea);
				
				For i = 1 To 50 Do
					
					If Not Common.SpreadsheetDocumentFitsPage(SpreadsheetDocument, AreasToBeChecked) Or i = 50 Then
						
						PageNumber = PageNumber + 1;
						PageNumberArea.Parameters.PageNumber = PageNumber;
						SpreadsheetDocument.Put(PageNumberArea);
						Break;
						
					Else
						SpreadsheetDocument.Put(EmptyLineArea);
					EndIf;
					
				EndDo;
				
				#EndRegion
				
				PrintManagement.SetDocumentPrintArea(SpreadsheetDocument, FirstLineNumber, PrintObjects, Header.Ref);
				
			EndDo;
			
		EndIf;
		
	EndDo;
	
	SpreadsheetDocument.FitToPage = True;
	
	Return SpreadsheetDocument;
	
EndFunction

Function GetTransferOrderQuery()
		
		Return
		"SELECT ALLOWED
		|	TransferOrder.Ref AS Ref,
		|	TransferOrder.Number AS Number,
		|	TransferOrder.Date AS Date,
		|	TransferOrder.Company AS Company,
		|	TransferOrder.StructuralUnit AS FieldFrom,
		|	TransferOrder.StructuralUnitPayee AS Contract,
		|	CAST(TransferOrder.Comment AS STRING(1024)) AS Comment,
		|	TransferOrder.SalesOrderPosition AS SalesOrderPosition,
		|	TransferOrder.StructuralUnitPayee AS FieldTo
		|INTO TransferOrder
		|FROM
		|	Document.TransferOrder AS TransferOrder
		|WHERE
		|	TransferOrder.Ref = &CurrentDocument
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT ALLOWED
		|	TransferOrder.Ref AS Ref,
		|	TransferOrder.Number AS DocumentNumber,
		|	TransferOrder.Date AS DocumentDate,
		|	TransferOrder.Company AS Company,
		|	Companies.LogoFile AS CompanyLogoFile,
		|	TransferOrder.Contract AS Contract,
		|	TransferOrder.Comment AS Comment,
		|	TransferOrder.FieldTo AS FieldTo,
		|	TransferOrder.FieldFrom AS FieldFrom
		|INTO Header
		|FROM
		|	TransferOrder AS TransferOrder
		|		LEFT JOIN Catalog.Companies AS Companies
		|		ON TransferOrder.Company = Companies.Ref
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT ALLOWED
		|	TransferOrderInventory.Ref AS Ref,
		|	TransferOrderInventory.LineNumber AS LineNumber,
		|	TransferOrderInventory.Products AS Products,
		|	TransferOrderInventory.Characteristic AS Characteristic,
		|	TransferOrderInventory.Quantity AS Quantity,
		|	TransferOrderInventory.MeasurementUnit AS MeasurementUnit
		|INTO FilteredInventory
		|FROM
		|	Header AS Header
		|		INNER JOIN Document.TransferOrder.Inventory AS TransferOrderInventory
		|		ON Header.Ref = TransferOrderInventory.Ref
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT
		|	Header.Ref AS Ref,
		|	Header.DocumentNumber AS DocumentNumber,
		|	Header.DocumentDate AS DocumentDate,
		|	Header.Company AS Company,
		|	Header.CompanyLogoFile AS CompanyLogoFile,
		|	Header.Contract AS Contract,
		|	Header.Comment AS Comment,
		|	MIN(FilteredInventory.LineNumber) AS LineNumber,
		|	CatalogProducts.SKU AS SKU,
		|	CASE
		|		WHEN (CAST(CatalogProducts.DescriptionFull AS STRING(1024))) <> """"
		|			THEN CAST(CatalogProducts.DescriptionFull AS STRING(1024))
		|		ELSE CatalogProducts.Description
		|	END AS ProductDescription,
		|	ISNULL(CatalogUOM.Description, CatalogUOMClassifier.Description) AS UOM,
		|	SUM(FilteredInventory.Quantity) AS Quantity,
		|	FilteredInventory.Products AS Products,
		|	FilteredInventory.Characteristic AS Characteristic,
		|	FilteredInventory.MeasurementUnit AS MeasurementUnit,
		|	Header.FieldTo AS FieldTo,
		|	Header.FieldFrom AS FieldFrom
		|INTO Tabular
		|FROM
		|	Header AS Header
		|		INNER JOIN FilteredInventory AS FilteredInventory
		|		ON Header.Ref = FilteredInventory.Ref
		|		LEFT JOIN Catalog.Products AS CatalogProducts
		|		ON (FilteredInventory.Products = CatalogProducts.Ref)
		|		LEFT JOIN Catalog.ProductsCharacteristics AS CatalogCharacteristics
		|		ON (FilteredInventory.Characteristic = CatalogCharacteristics.Ref)
		|		LEFT JOIN Catalog.UOM AS CatalogUOM
		|		ON (FilteredInventory.MeasurementUnit = CatalogUOM.Ref)
		|		LEFT JOIN Catalog.UOMClassifier AS CatalogUOMClassifier
		|		ON (FilteredInventory.MeasurementUnit = CatalogUOMClassifier.Ref)
		|
		|GROUP BY
		|	Header.DocumentNumber,
		|	Header.DocumentDate,
		|	Header.Company,
		|	Header.Ref,
		|	Header.CompanyLogoFile,
		|	Header.Contract,
		|	Header.Comment,
		|	CatalogProducts.SKU,
		|	CASE
		|		WHEN (CAST(CatalogProducts.DescriptionFull AS STRING(1024))) <> """"
		|			THEN CAST(CatalogProducts.DescriptionFull AS STRING(1024))
		|		ELSE CatalogProducts.Description
		|	END,
		|	CASE
		|		WHEN CatalogProducts.UseCharacteristics
		|			THEN CatalogCharacteristics.Description
		|		ELSE """"
		|	END,
		|	ISNULL(CatalogUOM.Description, CatalogUOMClassifier.Description),
		|	FilteredInventory.Products,
		|	FilteredInventory.Characteristic,
		|	FilteredInventory.MeasurementUnit,
		|	Header.FieldTo,
		|	Header.FieldFrom
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT
		|	Tabular.Ref AS Ref,
		|	Tabular.DocumentNumber AS DocumentNumber,
		|	Tabular.DocumentDate AS DocumentDate,
		|	Tabular.Company AS Company,
		|	Tabular.CompanyLogoFile AS CompanyLogoFile,
		|	Tabular.Contract AS Contract,
		|	Tabular.Comment AS Comment,
		|	Tabular.LineNumber AS LineNumber,
		|	Tabular.SKU AS SKU,
		|	Tabular.ProductDescription AS ProductDescription,
		|	Tabular.Quantity AS Quantity,
		|	Tabular.Products AS Products,
		|	Tabular.Characteristic AS Characteristic,
		|	Tabular.MeasurementUnit AS MeasurementUnit,
		|	Tabular.UOM AS UOM,
		|	FALSE AS ContentUsed,
		|	Tabular.FieldTo AS FieldTo,
		|	Tabular.FieldFrom AS FieldFrom
		|FROM
		|	Tabular AS Tabular
		|
		|ORDER BY
		|	Tabular.DocumentNumber,
		|	LineNumber
		|TOTALS
		|	MAX(DocumentNumber),
		|	MAX(DocumentDate),
		|	MAX(Company),
		|	MAX(CompanyLogoFile),
		|	MAX(Contract),
		|	MAX(Comment),
		|	COUNT(LineNumber),
		|	SUM(Quantity),
		|	MAX(FieldTo),
		|	MAX(FieldFrom)
		|BY
		|	Ref";
		
		
	EndFunction
	
Function GetFullDescription(Field, DocumentDate)
	Return DriveServer.InfoAboutLegalEntityIndividual(Field, DocumentDate).FullDescr;
EndFunction

#EndRegion

#EndRegion

#EndIf