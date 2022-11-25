#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region EventHandlers

Procedure ChoiceDataGetProcessing(ChoiceData, Parameters, StandardProcessing)
	
	NativeLanguagesSupportServer.ChoiceDataGetProcessing(
		ChoiceData,
		Parameters,
		StandardProcessing,
		Metadata.Catalogs.ExchangeWithOfflinePeripheralsRules);
	
EndProcedure

Procedure PresentationGetProcessing(Data, Presentation, StandardProcessing)
	
	NationalLanguageSupportClientServer.PresentationGetProcessing(Data, Presentation, StandardProcessing);
	
EndProcedure

Procedure PresentationFieldsGetProcessing(Fields, StandardProcessing)
	
	NationalLanguageSupportClientServer.PresentationFieldsGetProcessing(Fields, StandardProcessing);
	
EndProcedure

#EndRegion
	
#Region ProgramInterface

// Receives object attributes which it is required to lock from change
//
// Parameters:
//  No
//
// Returns:
//  Array - lockable object attributes
//
Function GetObjectAttributesBeingLocked() Export

	Result = New Array;
	Result.Add("PeripheralsType");
	
	Return Result;

EndFunction

#EndRegion

#Region PrintInterface

// Function forms print form Product codes
//
Function GeneratePrintFormProductsCodes(ObjectsArray, PrintObjects, PrintParameters)
	
	// MultilingualSupport
	PrintParams = PrintParameters.Result;
	If PrintParams = Undefined Then
		LanguageCode = NationalLanguageSupportClientServer.DefaultLanguageCode();
	Else
		LanguageCode = PrintParams.LanguageCode;
	EndIf;
	
	If LanguageCode <> CurrentLanguage().LanguageCode Then 
		SessionParameters.LanguageCodeForOutput = LanguageCode;
	EndIf;
	// End MultilingualSupport
	
	SpreadsheetDocument = New SpreadsheetDocument;
	SpreadsheetDocument.PrintParametersName = "PRINT_PARAMETERS_ProductCodes";
	
	Template = PrintManagement.PrintFormTemplate("Catalog.ExchangeWithOfflinePeripheralsRules.PF_MXL_ProductCodes", LanguageCode);
	FirstDocument = True;
	
	For Each Object In ObjectsArray Do
		
		PeripheralsOfflineServerCall.RefreshProductProduct(Object);
		
		If Not FirstDocument Then
			SpreadsheetDocument.PutHorizontalPageBreak();
		EndIf;
		
		FirstDocument = False;
		FirstLineNumber = SpreadsheetDocument.TableHeight + 1;
		
		TemplateArea = Template.GetArea("Title");
		TemplateArea.Parameters.HeaderText = NStr("en = 'Goods codes'; ru = 'Коды товаров';pl = 'Kody towarów';es_ES = 'Códigos de mercancías';es_CO = 'Códigos de mercancías';tr = 'Ürün kodları';it = 'Codici Merci';de = 'Warencodes'", LanguageCode);
		TemplateArea.Parameters.ExchangeRule  = Object;
		SpreadsheetDocument.Put(TemplateArea);
		
		AreaCode   = Template.GetArea("TableHeader|Code");
		AreaProduct = Template.GetArea("TableHeader|Product");
		SpreadsheetDocument.Put(AreaCode);
		SpreadsheetDocument.Join(AreaProduct);
		
		AreaCode   = Template.GetArea("String|Code");
		AreaProduct = Template.GetArea("String|Product");
		
		Products = PeripheralsOfflineServerCall.GetGoodsTableForRule(Object, Catalogs.PriceTypes.EmptyRef());
		For Each TSRow In Products Do
			
			AreaCode.Parameters.Code = TSRow.Code;
			SpreadsheetDocument.Put(AreaCode);
			
			If TSRow.Used Then
				AreaProduct.Parameters.Product = TSRow.Description;
			Else
				AreaProduct.Parameters.Product = "";
			EndIf;
			SpreadsheetDocument.Join(AreaProduct);
			
		EndDo;
		
		TemplateArea = Template.GetArea("Total");
		SpreadsheetDocument.Put(TemplateArea);
		
		// Output signatures.
		TemplateArea = Template.GetArea("Signatures");
		TemplateArea.Parameters.Responsible = Users.CurrentUser();
		SpreadsheetDocument.Put(TemplateArea);
		
		PrintManagement.SetDocumentPrintArea(SpreadsheetDocument, FirstLineNumber, PrintObjects, Object);
	
	EndDo;
	
	Return SpreadsheetDocument;
	
EndFunction

// Generate printed forms of objects
//
Procedure Print(ObjectsArray, PrintParameters, PrintFormsCollection, PrintObjects, OutputParameters) Export
	
	If PrintManagement.TemplatePrintRequired(PrintFormsCollection, "ProductCodes") Then
		
		PrintManagement.OutputSpreadsheetDocumentToCollection(
			PrintFormsCollection,
			"ProductCodes",
			NStr("en = 'Product codes'; ru = 'Коды номенклатуры';pl = 'Kody produktów';es_ES = 'Códigos de productos';es_CO = 'Códigos de productos';tr = 'Ürün kodları';it = 'Codici articolo';de = 'Produktcodes'"),
			GeneratePrintFormProductsCodes(ObjectsArray, PrintObjects, PrintParameters));
		
	EndIf;
	
EndProcedure

// Fills list of catalog printing commands "Exchange rules with peripherals offline"
// 
// Parameters:
//   PrintCommands - ValueTable - see fields' content in the PrintManagement.CreatePrintCommandsCollection function.
//
Procedure AddPrintCommands(PrintCommands) Export
	
	// Product codes
	PrintCommand = PrintCommands.Add();
	PrintCommand.ID = "ProductCodes";
	PrintCommand.Presentation = NStr("en = 'Goods codes'; ru = 'Коды товаров';pl = 'Kody towarów';es_ES = 'Códigos de mercancías';es_CO = 'Códigos de mercancías';tr = 'Ürün kodları';it = 'Codici Merci';de = 'Warencodes'");
	PrintCommand.FormsList = "ItemForm,ListForm,ChoiceForm";
	PrintCommand.CheckPostingBeforePrint = False;
	PrintCommand.Order = 1;
	
EndProcedure

#EndRegion

#EndIf