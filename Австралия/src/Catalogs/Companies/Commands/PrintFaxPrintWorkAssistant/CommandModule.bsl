
&AtClient
Procedure CommandProcessing(CommandParameter, CommandExecuteParameters)
	
	StructureAdvancedOptions = New Structure;
	StructureAdvancedOptions.Insert("FormTitle", NStr("en = 'How to create signature image fast and easily?'; ru = 'Как быстро и просто создать факсимиле?';pl = 'Jak szybko i łatwo utworzyć faksymile i pieczątkę?';es_ES = '¿Cómo crear un facsímil rápida- y fácilmente?';es_CO = '¿Cómo crear un facsímil rápida- y fácilmente?';tr = 'Kolayca imza görseli oluşturma';it = 'Come creare una immagine di firma in modo facile e rapido?';de = 'Wie kann man schnell und einfach ein Signaturbild erstellen?'"));
	StructureAdvancedOptions.Insert("ID", Undefined);
	StructureAdvancedOptions.Insert("Result", Undefined);
	StructureAdvancedOptions.Insert("PrintInfo", Undefined);
	StructureAdvancedOptions.Insert("AdditionalParameters", New Structure);
	
	PrintCommandParameters = New Array;
	PrintCommandParameters.Add(CommandParameter);
	
	PrintManagementClient.ExecutePrintCommand("Catalog.Companies", "PrintFaxPrintWorkAssistant", PrintCommandParameters, CommandExecuteParameters, StructureAdvancedOptions);
	
EndProcedure
