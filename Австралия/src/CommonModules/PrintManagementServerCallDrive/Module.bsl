#Region Public

// Checks whether the AdditionalAttributes exists among the object Tabular sections.
//
// Parameters:
//  DocumentObject - DocumentRef,String - a document ref to search for the attribute.
//
// Returns:
//  Boolean - True if TabularSections "AdditionalAttributes" is found.
Function HasAdditionalAttributes(DocumentObject) Export
    Return NOT (DocumentObject.Metadata().TabularSections.Find("AdditionalAttributes") = Undefined);
EndFunction 

// The function returns a string of codes specified in the parameter PrintSettings
//
// Parameters:
//   PrintSettings - Structure:
//     * PrintCommandID - String - Name of print command.
//     * MetadataName - String - Name of the metadata object.
//     * User - CatalogRef.Users - Current user.
//     * OriginalCopy - Boolean - whether to print ORIGINAL or COPY watermark Original = True, Copy = False.
//     * Language - String - One of Configuration language names.
//     * Copies - Number - number of copies need to print.
//     * HSCode - Boolean - whether to print the HSCode of Product item.
//     * ItemNumber - Boolean - whether to print the SKU code of Product item.
//     * SystemCode - Boolean - whether to print the SystemCode of Product item.
//     * Barcode - Boolean - whether to print the BarCode of Product item.
//     * CodesPosition - EnumRef.CodesPositionInPrintForms - where to print codes in printed form.
//     * Discount - Boolean - whether to print Discount column and Discount totals.
//     * DoNotShowAgain - Boolean - whether to show PrintOptions form at next time.
//
//   Product - CatalogRef.Products - product for which need to get codes.
//   Characteristic - CatalogRef.ProductsCharacteristics - product Characteristic for which need to get codes.
//   Batch - CatalogRef.ProductsBatches - product Batch for which need to get codes.
//
// Returns:
//   String.
//
Function GetCodesPresentation(PrintSettings, Product, Characteristic = Undefined, Batch = Undefined) Export
	StringReturn = "";
	Divider = "";
	
	If Not ValueIsFilled(Product) Then
		Return StringReturn;	
	EndIf;
	
	PrintOptions = PrintSettings.CodesPosition;
    If PrintOptions = Enums.CodesPositionInPrintForms.DontDisplay Then        
		Return StringReturn;
	ElsIf PrintOptions = Enums.CodesPositionInPrintForms.SeparateColumn Then
		Divider = Chars.LF;	
	ElsIf PrintOptions = Enums.CodesPositionInPrintForms.ProductColumn Then
		Divider = "; ";	
	EndIf;
	
	If PrintSettings.ItemNumber Then
		Code = TrimAll(Product.SKU);
		If Code = "" Then
			Code = "- ";
		EndIf;
		StringReturn = StringReturn + Code;
	EndIf;
	If PrintSettings.HSCode Then
		Code = "";
		If ValueIsFilled(Product.HSCode) Then
			Code = TrimAll(Product.HSCode.Code);
		EndIf;
		If Code = "" Then
			Code = "- ";
		EndIf;
		StringReturn = StringReturn + ?(StringReturn = "", "", Divider) + Code;
	EndIf;
	If PrintSettings.SystemCode Then
		Code = TrimAll(Product.Code);
		If Code = "" Then
			Code = "- ";
		EndIf;
		StringReturn = StringReturn + ?(StringReturn = "", "", Divider) + Code;
	EndIf;
	If PrintSettings.Barcode Then
		Code = GetBarcode(Product, Characteristic, Batch);
		If Code = "" Then
			Code = "- ";
		EndIf;
		StringReturn = StringReturn + ?(StringReturn = "", "", Divider) + Code;
	EndIf;

	Return StringReturn;
EndFunction

// Return structure with Print options saved into InformationRegistry for specified user
// Parameters:
//   MetadataObjectOrName - String,DocumentRef - Name or reference to to print document.
//   PrintCommandID - String - Name of print command.
//   User - CatalogRef.Users - Current user.
Function GetPrintOptionsByUsers(MetadataObjectOrName, PrintCommandID, User = Undefined) Export
    CurrentUser = ?(User = Undefined, SessionParameters.CurrentUser, User);
    Options = NewPrintOptionsStructure(True);
    
    If TypeOf(MetadataObjectOrName)=Type("String") Then
        MetadataName = MetadataObjectOrName;   
    Else
        MetadataName = MetadataObjectOrName.Metadata().Name;
    EndIf;    
    
    Query = New Query;
    Query.Text = 
        "SELECT
        |	PrintOptionsByUsers.PrintCommandID AS PrintCommandID,
        |	PrintOptionsByUsers.MetadataName AS MetadataName,
        |	PrintOptionsByUsers.User AS User,
        |	PrintOptionsByUsers.OriginalCopy AS OriginalCopy,
        |	PrintOptionsByUsers.LanguageCode AS LanguageCode,
        |	PrintOptionsByUsers.Copies AS Copies,
        |	PrintOptionsByUsers.HSCode AS HSCode,
        |	PrintOptionsByUsers.ItemNumber AS ItemNumber,
        |	PrintOptionsByUsers.SystemCode AS SystemCode,
        |	PrintOptionsByUsers.Barcode AS Barcode,
        |	PrintOptionsByUsers.CodesPosition AS CodesPosition,
        |	PrintOptionsByUsers.Discount AS Discount,
        |	PrintOptionsByUsers.AdditionalAttributes AS AdditionalAttributes,
        |	PrintOptionsByUsers.DoNotShowAgain AS DoNotShowAgain,
        |	PrintOptionsByUsers.PriceBeforeDiscount AS PriceBeforeDiscount,
        |	PrintOptionsByUsers.NetAmount AS NetAmount,
        |	PrintOptionsByUsers.VAT AS VAT,
        |	PrintOptionsByUsers.LineTotal AS LineTotal
        |FROM
        |	InformationRegister.PrintOptionsByUsers AS PrintOptionsByUsers
        |WHERE
        |	PrintOptionsByUsers.PrintCommandID = &PrintCommandID
        |	AND PrintOptionsByUsers.MetadataName = &MetadataName
        |	AND PrintOptionsByUsers.User = &User";
    
    Query.SetParameter("MetadataName", MetadataName);
    Query.SetParameter("PrintCommandID", PrintCommandID);
    Query.SetParameter("User", CurrentUser);
    
    SetPrivilegedMode(True);
    
    QueryResult = Query.Execute();
    
    SelectionDetailRecords = QueryResult.Select();
    
    SetPrivilegedMode(False);
    
    If Not QueryResult.IsEmpty() Then
        While SelectionDetailRecords.Next() Do
           FillPropertyValues(Options, SelectionDetailRecords);
        EndDo;
    EndIf;        
    Return Options;
EndFunction

// Prepare the Strtucture for PrintOptions DataProcessor
// Parameters:
//   NeedFillDefaults - Boolean - whether to fill by default values.
// 
// Returns:
//   PrintParameters - Structure:
//     * PrintCommandID - String - Name of print command, Default = Undefined.
//     * MetadataName - String - Name of the metadata object, Default = Undefined.
//     * User - CatalogRef.Users - Current user, Default = Undefined.
//     * OriginalCopy - Boolean - Default = Undefined.
//     * Language - String - One of Configuration language names, Default = language for current user.
//     * Copies - Number - number of copies need to print, Default = 1.
//     * HSCode - Boolean - whether to print the HSCode of Product item, Default = Undefined.
//     * ItemNumber - Boolean - whether to print the SKU code of Product item, Default = Undefined.
//     * SystemCode - Boolean - whether to print the SystemCode of Product item, Default = Undefined.
//     * Barcode - Boolean - whether to print the BarCode of Product item, Default = Undefined.
//     * CodesPosition - EnumRef.CodesPositionInPrintForms - where to print codes in printed form, Default = DontDisplay.
//     * Discount - Boolean - whether to print Discount column and Discount totals, Default = Undefined.
//     * DoNotShowAgain - Boolean - whether to show PrintOptions form at next time, Default = Undefined.
Function NewPrintOptionsStructure(NeedFillDefaults = False) Export
    
    SetPrivilegedMode(True);

	UserLanguageCode = DriveServer.GetCurrentUserLanguageCode();
    PrintParameters = New Structure;
	
	PrintParameters.Insert("PrintCommandID", Undefined);
	PrintParameters.Insert("MetadataName", Undefined);
	PrintParameters.Insert("User", Undefined);
	PrintParameters.Insert("OriginalCopy", ?(NeedFillDefaults, True, Undefined));
	PrintParameters.Insert("LanguageCode", ?(NeedFillDefaults, UserLanguageCode, Undefined));
	PrintParameters.Insert("Copies", 1);
	PrintParameters.Insert("HSCode", Undefined);
	PrintParameters.Insert("ItemNumber", Undefined);
	PrintParameters.Insert("SystemCode", Undefined);
	PrintParameters.Insert("Barcode", Undefined);
	PrintParameters.Insert("CodesPosition", ?(NeedFillDefaults, Enums.CodesPositionInPrintForms.DontDisplay, Undefined));
	PrintParameters.Insert("AdditionalAttributes", Undefined);
	PrintParameters.Insert("DoNotShowAgain", ?(NeedFillDefaults, False, Undefined));
	PrintParameters.Insert("Discount", Undefined);
	PrintParameters.Insert("PriceBeforeDiscount", Undefined);
	PrintParameters.Insert("NetAmount", Undefined);
	PrintParameters.Insert("VAT", Undefined);
	PrintParameters.Insert("LineTotal", Undefined);
	
    SetPrivilegedMode(False);
    
    Return PrintParameters;
EndFunction    

Function ProgramPrintingPrintOptionsStructure(NeedFillDefaults = False) Export
	
	UserLanguageCode = DriveServer.GetCurrentUserLanguageCode();
	PrintParameters = New Structure;
	
	PrintParameters.Insert("PrintCommandID", "");
	PrintParameters.Insert("MetadataName", "");
	PrintParameters.Insert("User", Catalogs.Users.EmptyRef());
	PrintParameters.Insert("OriginalCopy", ?(NeedFillDefaults, True, False));
	PrintParameters.Insert("LanguageCode", ?(NeedFillDefaults, UserLanguageCode, Undefined));
	PrintParameters.Insert("Copies", 1);
	PrintParameters.Insert("HSCode", False);
	PrintParameters.Insert("ItemNumber", False);
	PrintParameters.Insert("SystemCode", False);
	PrintParameters.Insert("Barcode", False);
	PrintParameters.Insert("CodesPosition", ?(NeedFillDefaults, Enums.CodesPositionInPrintForms.DontDisplay, Enums.CodesPositionInPrintForms.EmptyRef()));
	PrintParameters.Insert("Discount", False);
	PrintParameters.Insert("AdditionalAttributes", False);
	PrintParameters.Insert("DoNotShowAgain", ?(NeedFillDefaults, False, True));
	PrintParameters.Insert("PriceBeforeDiscount", False);
	PrintParameters.Insert("NetAmount", True);
	PrintParameters.Insert("VAT", True);
	PrintParameters.Insert("LineTotal", True);
	
	Return PrintParameters;
	
EndFunction

// Return value of functional option
Function GetFunctionalOptionValue(Name) Export
	
	Return GetFunctionalOption(Name);
	
EndFunction

// Checking: the document can be printed with additional print options form.
Function IsDocumentInPrintOptionsList(PrintCommandID) Export
	
	List = New ValueList;
	
	List.Add("ADVANCEPAYMENTINVOICE");
	List.Add("CREDITNOTE");
	List.Add("DEBITNOTE");
	List.Add("DELIVERYNOTE");
	List.Add("GOODSRECEIVEDNOTE");
	List.Add("ORDERCONFIRMATION");
	List.Add("PICKLIST");
	List.Add("PROFORMAINVOICE");
	List.Add("PROFORMAINVOICEALLVARIANTS");
	List.Add("PURCHASEORDERINTERMSOFSUPPLIER");
	List.Add("PURCHASEORDERTEMPLATE");
	List.Add("QUOTE");
	List.Add("QUOTEALLVARIANTS");
	List.Add("RECONCILIATIONSTATEMENT");
	List.Add("REQUISITION");
	List.Add("REQUISITIONORDERTEMPLATE");
	List.Add("RMAREQUEST");
	List.Add("SALESINVOICE");
	List.Add("CLOSINGINVOICE");
	List.Add("CLOSINGINVOICENOANNEX");
	List.Add("SIMPLIFIEDTAXINVOICE");
	List.Add("TAXINVOICE");
	List.Add("VATINVOICEFORICT");
	List.Add("WORKORDER");
	List.Add("EXPENSECLAIM");
	List.Add("PACKINGSLIP");
	List.Add("PRODUCTIONTASKSLIST");
	
	Return ?(List.FindByValue(Upper(PrintCommandID)) = Undefined, False, True);
	
EndFunction

Function GetStructureOptionsInDocuments(PrintCommandID) Export
	
	StructureOptionsInDocuments = New Structure;
	
	StructureOptionsInDocuments.Insert("DocumentInPrintOptionsList",	IsDocumentInPrintOptionsList(PrintCommandID));
	StructureOptionsInDocuments.Insert("CustomColumns",					IsDocumentCustomColumns(PrintCommandID));
	
	Return StructureOptionsInDocuments;
	
EndFunction

Function CheckPrintFormSettings(PrintCommandID) Export

	If IsDocumentInPrintOptionsList(PrintCommandID)
		Or GetFunctionalOptionValue("UseAdditionalLanguage1")
		Or GetFunctionalOptionValue("UseAdditionalLanguage2")
		Or GetFunctionalOptionValue("UseAdditionalLanguage3")
		Or GetFunctionalOptionValue("UseAdditionalLanguage4") Then
	    Return True;
	Else
		Return False;
	EndIf; 
	
EndFunction

#EndRegion

#Region Private

// The function obtaining and return a barcode for a product
Function GetBarcode(Product, Characteristic, Batch)
	Query = New Query;
	Query.Text = 
	"SELECT TOP 1
	|	Barcodes.Barcode AS Barcode
	|FROM
	|	InformationRegister.Barcodes AS Barcodes
	|WHERE
	|	Barcodes.Products = &Products";
	Query.SetParameter("Products", Product);
	If ValueIsFilled(Characteristic) Then
		Query.Text = Query.Text + "
		| AND Barcodes.Characteristic = &Characteristic";
		Query.SetParameter("Characteristic", Characteristic);
	EndIf;
	If ValueIsFilled(Batch) Then
		Query.Text = Query.Text + "
		| AND Barcodes.Batch = &Batch";
		Query.SetParameter("Batch", Batch);
	EndIf;
	
	Result = Query.Execute();
	If Result.IsEmpty() Then
		Return "";
	EndIf;
	Selection = Result.Select();
	Selection.Next();
	
	Return TrimAll(Selection.Barcode);
EndFunction

Function IsDocumentCustomColumns(PrintCommandID)
	
	List = New ValueList;
	
	List.Add("ORDERCONFIRMATION");
	List.Add("PROFORMAINVOICE");
	List.Add("PROFORMAINVOICEALLVARIANTS");
	List.Add("PURCHASEORDERINTERMSOFSUPPLIER");
	List.Add("PURCHASEORDERTEMPLATE");
	List.Add("QUOTE");
	List.Add("QUOTEALLVARIANTS");
	List.Add("SALESINVOICE");
	List.Add("WORKORDER");
	
	Return ?(List.FindByValue(Upper(PrintCommandID)) = Undefined, False, True);
	
EndFunction

#EndRegion