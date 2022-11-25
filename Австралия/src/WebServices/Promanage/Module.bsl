
#Region Private

Function GetProducts()
	
	ProductType = XDTOFactory.Type("http://www.1ci.com/ProManage", "Product");
	
	Data = New XMLWriter;
	Data.SetString();
	Data.WriteXMLDeclaration();
	
	Data.WriteStartElement("v8msg");
	
	Selection = SelectProducts();
	
	While Selection.Next() Do
		
		Products = XDTOFactory.Create(ProductType);
		Products.UUID = XMLString(Selection.Ref.UUID());
		Products.Description		= Selection.Description;
		Products.ProductGroupName	= Selection.ProductGroupName;
		Products.Code				= Selection.Code;
		
		XDTOFactory.WriteXML(Data, Products);
			
	EndDo;
	
	Data.WriteEndElement();
	Message = Data.Close();
	
	Return Message;
	
EndFunction

Function GetProductionOrders(NodeCode, MessageNoReceived)
	
	Node = ExchangePlans.Promanage.FindByCode(NodeCode);
	
	If Not ValueIsFilled(Node) Then
		Return "";
	EndIf;
	
	NodeObject = Node.GetObject();
	LastSentNo =  Node.SentNo;
	
	ExchangeNodeAttributes = Common.ObjectAttributesValues(Node, "WebService, Username, UseLocalService");
	
	Headers = New Map;
	Headers.Insert("Content-type", "application/json");	
	
	If ExchangeNodeAttributes.UseLocalService Then	 
		HTTPConnection = New HTTPConnection(ExchangeNodeAttributes.WebService);
	Else
		
		SetPrivilegedMode(True);
		PasswordFromStorage = Common.ReadDataFromSecureStorage(Node, "Password");
		SetPrivilegedMode(False);
		
		SecureConnection = New OpenSSLSecureConnection();
		HTTPConnection = New HTTPConnection(ExchangeNodeAttributes.WebService, , ExchangeNodeAttributes.Username, PasswordFromStorage, , , SecureConnection);
		
	EndIf;
	
	HTTPRequest = New HTTPRequest("/Getstatus?pQueueID=0&pCustQueueID=" + LastSentNo, Headers);
	
	Result = HTTPConnection.Get(HTTPRequest);
	ResponseBody = Result.GetBodyAsString(TextEncoding.UTF8);
	
	JSONReader = New JSONReader;
	JSONReader.SetString(ResponseBody);
	
	If Not IsBlankString(ResponseBody) Then
		ResponseStructure = ReadJSON(JSONReader);
		
		If ResponseStructure.error = 0 Then	
			NodeObject.ReceivedNo = LastSentNo;
		EndIf;
		
		NodeObject.Write();
		
		ExchangePlans.DeleteChangeRecords(Node, LastSentNo);
		
	EndIf;
	
	ProductionOrderType = XDTOFactory.Type("http://www.1ci.com/ProManage", "ProductionOrder");
	
	Data = New XMLWriter;
	Data.SetString();
	Data.WriteXMLDeclaration();
	
	MessageWriter = ExchangePlans.CreateMessageWriter();
	MessageWriter.BeginWrite(Data, Node);
	
	Selection = ExchangePlans.SelectChanges(Node, MessageWriter.MessageNo);
	
	While Selection.Next() Do
		
		WIPObject = Selection.Get();
		
		If TypeOf(WIPObject) <> Type("DocumentObject.ManufacturingOperation") Then
			Continue;
		EndIf;
		
		ProductionOrder = XDTOFactory.Create(ProductionOrderType);
		ProductionOrder.UUID = XMLString(WIPObject.Ref.UUID());
		ProductionOrder.ProductUUID = XMLString(WIPObject.Products.UUID());
		ProductionOrder.ProductCode = Common.ObjectAttributeValue(WIPObject.Products, "Code");
		ProductionOrder.Quantity = WIPObject.Quantity;
		ProductionOrder.Number = WIPObject.Number;
		ProductionOrder.Status = XMLString(WIPObject.Status);
		
		If ValueIsFilled(WIPObject.BasisDocument) Then
			ProductionOrder.DeliveryDate = XMLString(Common.ObjectAttributeValue(WIPObject.BasisDocument, "Finish"));
		Else
			ProductionOrder.DeliveryDate = XMLString(Date('00010101'));
		EndIf;
		
		XDTOFactory.WriteXML(Data, ProductionOrder);
				
	EndDo;
	
	MessageWriter.EndWrite();
	Message = Data.Close();
	
	Return Message;
	
EndFunction

Function GetProductionOrderOperations(ProductionOrderUUID)
		
	WIP = Documents.ManufacturingOperation.GetRef(New UUID(ProductionOrderUUID));
	WIPObject = WIP.GetObject();
	OperationsType = XDTOFactory.Type("http://www.1ci.com/ProManage", "ProductionOrderOperations");
	
	Data = New XMLWriter;
	Data.SetString();
	Data.WriteXMLDeclaration();
	
	Data.WriteStartElement("v8msg");
	
	If WIPObject <> Undefined Then
		
		Selection = SelectProductionOrderOperations(WIP);
		While Selection.Next() Do
			
			Operation = XDTOFactory.Create(OperationsType);
			FillPropertyValues(Operation, Selection, , "WorkCenterCode, NumberOfProductPerCycle");
			
			If Selection.CalculationMethod <> Enums.BOMOperationCalculationMethod.Proportional Then
				Operation.NumberOfProductPerCycle = Selection.NumberOfProductPerCycle;
			EndIf;
			
			Operation.ProductionOrderUUID = ProductionOrderUUID;
			Operation.OperationUUID = XMLString(Selection.Activity.UUID());
			
			If Not IsBlankString(Selection.WorkCenterCode) Then
				Operation.WorkCenterCode = Selection.WorkCenterCode;
			EndIf;
			
			XDTOFactory.WriteXML(Data, Operation);
			
		EndDo;
		
	EndIf;
	
	Data.WriteEndElement();
	Message = Data.Close();
	
	Return Message;
	
EndFunction

Function GetProductOperation()
		
	ProductOperationType = XDTOFactory.Type("http://www.1ci.com/ProManage", "ProductOperation");
	
	Data = New XMLWriter;
	Data.SetString();
	Data.WriteXMLDeclaration();
	
	Data.WriteStartElement("v8msg");
	
	Selection = SelectBOMs();
	
	While Selection.Next() Do
		
		For Each OperationRow In Selection.Ref.Operations Do
			
			ProductOperation = XDTOFactory.Create(ProductOperationType);
			ProductOperation.ProductUUID = XMLString(Selection.Product.UUID());
			ProductOperation.OperationUUID = XMLString(OperationRow.Activity.UUID());
			ProductOperation.NumberOfProductPerCycle = Selection.Quantity;
			
			XDTOFactory.WriteXML(Data, ProductOperation);
			
		EndDo;
		
	EndDo;
	
	Message = Data.Close();
	
	Return Message;
	
EndFunction

Function GetBOMs()
	
	BillOfMaterialsType = XDTOFactory.Type("http://www.1ci.com/ProManage", "BillOfMaterials");
	BOMMaterialsType = XDTOFactory.Type("http://www.1ci.com/ProManage", "BOMMaterials");
	BOMOperationsType = XDTOFactory.Type("http://www.1ci.com/ProManage", "BOMOperations");
	
	Data = New XMLWriter;
	Data.SetString();
	Data.WriteXMLDeclaration();
	
	Data.WriteStartElement("v8msg");
	
	Selection = SelectBOMs();
	
	While Selection.Next() Do
		
		BillOfMaterials = XDTOFactory.Create(BillOfMaterialsType);
		BillOfMaterials.UUID = XMLString(Selection.Ref.UUID());
		BillOfMaterials.ProductUUID = XMLString(Selection.Product.UUID());
		BillOfMaterials.UnitOfAmount = Selection.Quantity;
		
		XDTOFactory.WriteXML(Data, BillOfMaterials);
		
		For Each MaterialRow In Selection.Ref.Content Do
			
			BOMMaterials = XDTOFactory.Create(BOMMaterialsType);
			BOMMaterials.BOMUUID = BillOfMaterials.UUID;
			BOMMaterials.MaterialUUID = XMLString(MaterialRow.Products.UUID());
			BOMMaterials.Quantity = MaterialRow.Quantity;
			
			XDTOFactory.WriteXML(Data, BOMMaterials);
			
		EndDo;

		For Each OperationRow In Selection.Ref.Operations Do
			
			BOMOperations = XDTOFactory.Create(BOMOperationsType);
			BOMOperations.BOMUUID = BillOfMaterials.UUID;
			BOMOperations.OperationUUID = XMLString(OperationRow.Activity.UUID());
			
			XDTOFactory.WriteXML(Data, BOMOperations);
			
		EndDo;
		
	EndDo;
	
	Data.WriteEndElement();
	Message = Data.Close();
	
	Return Message;
	
EndFunction

Function SelectProducts()
	
	Query = New Query;
	Query.Text = 
	"SELECT
	|	Products.Description AS Description,
	|	Products.Parent AS Parent,
	|	Products.Ref AS Ref,
	|	Products.Code AS Code
	|INTO Products
	|FROM
	|	Catalog.Products AS Products
	|WHERE
	|	NOT Products.DeletionMark
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	ISNULL(Parents.Description, """") AS ProductGroupName,
	|	Products.Ref AS Ref,
	|	Products.Description AS Description,
	|	Products.Code AS Code
	|FROM
	|	Products AS Products
	|		LEFT JOIN Catalog.Products AS Parents
	|		ON Products.Parent = Parents.Ref";
	
	QueryResult = Query.Execute();
	
	Return QueryResult.Select();
	
EndFunction

Function SelectBOMs()
	
	Query = New Query;
	Query.Text = 
	"SELECT
	|	BillsOfMaterials.Ref AS Ref,
	|	BillsOfMaterials.Owner AS Product,
	|	BillsOfMaterials.Quantity AS Quantity
	|FROM
	|	Catalog.BillsOfMaterials AS BillsOfMaterials
	|WHERE
	|	NOT BillsOfMaterials.DeletionMark
	|	AND BillsOfMaterials.Status = VALUE(Enum.BOMStatuses.Active)";
	
	QueryResult = Query.Execute();
	
	Return QueryResult.Select();
	
EndFunction

Function SelectProductionOrderOperations(WIP)
	
	Query = New Query;
	Query.Text = 
	"SELECT
	|	ManufacturingOperation.Ref AS Ref,
	|	ManufacturingOperation.Specification AS Specification
	|INTO WIP
	|FROM
	|	Document.ManufacturingOperation AS ManufacturingOperation
	|WHERE
	|	ManufacturingOperation.Ref = &WIP
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	ManufacturingOperationActivities.Quantity AS Quantity,
	|	ManufacturingOperationActivities.StandardTimeInUOM AS StandardTimeInUOM,
	|	ManufacturingActivities.Description AS Description,
	|	ManufacturingOperationActivities.Activity AS Activity,
	|	ISNULL(TimeUOMs.Description, """") AS TimeUOMDescription,
	|	ISNULL(TimeUOMs.Factor, 1) AS TimeUOMFactor,
	|	ISNULL(BillsOfMaterials.Quantity, 0) AS NumberOfProductPerCycle,
	|	WIP.Ref AS Ref,
	|	BillsOfMaterials.Ref AS BOM,
	|	ManufacturingActivities.Code AS OperationCode
	|INTO Operations
	|FROM
	|	WIP AS WIP
	|		LEFT JOIN Catalog.BillsOfMaterials AS BillsOfMaterials
	|		ON WIP.Specification = BillsOfMaterials.Ref
	|		INNER JOIN Document.ManufacturingOperation.Activities AS ManufacturingOperationActivities
	|			INNER JOIN Catalog.ManufacturingActivities AS ManufacturingActivities
	|			ON ManufacturingOperationActivities.Activity = ManufacturingActivities.Ref
	|			LEFT JOIN Catalog.TimeUOM AS TimeUOMs
	|			ON ManufacturingOperationActivities.TimeUOM = TimeUOMs.Ref
	|		ON WIP.Ref = ManufacturingOperationActivities.Ref
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	Operations.Quantity AS Quantity,
	|	Operations.StandardTimeInUOM AS StandardTimeInUOM,
	|	Operations.Description AS Description,
	|	Operations.Activity AS Activity,
	|	Operations.TimeUOMDescription AS TimeUOMDescription,
	|	Operations.TimeUOMFactor AS TimeUOMFactor,
	|	Operations.NumberOfProductPerCycle AS NumberOfProductPerCycle,
	|	MAX(ManufacturingActivitiesWorkCenterTypes.WorkcenterType) AS WorkcenterType,
	|	Operations.BOM AS BOM,
	|	Operations.OperationCode AS OperationCode
	|INTO OperationsWithWorkCenterType
	|FROM
	|	Operations AS Operations
	|		LEFT JOIN Catalog.ManufacturingActivities.WorkCenterTypes AS ManufacturingActivitiesWorkCenterTypes
	|		ON Operations.Activity = ManufacturingActivitiesWorkCenterTypes.Ref
	|
	|GROUP BY
	|	Operations.Description,
	|	Operations.Activity,
	|	Operations.TimeUOMDescription,
	|	Operations.Quantity,
	|	Operations.StandardTimeInUOM,
	|	Operations.TimeUOMFactor,
	|	Operations.NumberOfProductPerCycle,
	|	Operations.BOM,
	|	Operations.OperationCode
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	OperationsWithWorkCenterType.Quantity AS Quantity,
	|	OperationsWithWorkCenterType.StandardTimeInUOM AS StandardTimeInUOM,
	|	OperationsWithWorkCenterType.Description AS Description,
	|	OperationsWithWorkCenterType.Activity AS Activity,
	|	OperationsWithWorkCenterType.TimeUOMDescription AS TimeUOMDescription,
	|	OperationsWithWorkCenterType.TimeUOMFactor AS TimeUOMFactor,
	|	OperationsWithWorkCenterType.NumberOfProductPerCycle AS NumberOfProductPerCycle,
	|	ISNULL(CompanyResourceTypes.Code, """") AS WorkCenterCode,
	|	OperationsWithWorkCenterType.OperationCode AS OperationCode,
	|	BillsOfMaterialsOperations.CalculationMethod AS CalculationMethod
	|FROM
	|	OperationsWithWorkCenterType AS OperationsWithWorkCenterType
	|		INNER JOIN Catalog.CompanyResourceTypes AS CompanyResourceTypes
	|		ON OperationsWithWorkCenterType.WorkcenterType = CompanyResourceTypes.Ref
	|		LEFT JOIN Catalog.BillsOfMaterials.Operations AS BillsOfMaterialsOperations
	|		ON OperationsWithWorkCenterType.BOM = BillsOfMaterialsOperations.Ref
	|			AND OperationsWithWorkCenterType.Activity = BillsOfMaterialsOperations.Activity";
	
	Query.SetParameter("WIP", WIP);
	QueryResult = Query.Execute();
	
	Return QueryResult.Select();
	
EndFunction

#EndRegion
