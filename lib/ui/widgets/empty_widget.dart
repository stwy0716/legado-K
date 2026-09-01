import "package:flutter/material.dart";
class EmptyWidget extends StatelessWidget { final String message; const EmptyWidget({super.key, this.message = "暂无数据"}); @override Widget build(BuildContext context) => Center(child: Text(message)); }
