using System;
using System.Runtime.CompilerServices;
using System.Runtime.InteropServices;
using System.Runtime.InteropServices.Marshalling;
using System.Text;

partial class Main {

	[UnmanagedCallersOnly()]
	static void OnFrame()
	{
	}


	[UnmanagedCallersOnly()]
	static void OnInit()
	{
		Log($"C# initialized");
	}


	[LibraryImport("__Internal", EntryPoint="csharp_log", StringMarshalling = StringMarshalling.Utf8)]
	internal static partial void Log(string msg);

}