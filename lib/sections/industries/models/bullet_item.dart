class BulletItem {
	final String text;
	/// Can be an IconData, an emoji String, or null (treated as a generic dot)
	final Object? icon;
	const BulletItem({required this.text, required this.icon});
}